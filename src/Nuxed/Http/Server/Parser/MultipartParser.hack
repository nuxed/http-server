namespace Nuxed\Http\Server\Parser;

use namespace HH\Lib\Experimental\File;
use namespace HH\Lib\{C, Regex, Str, Vec};
use namespace Nuxed\Contract\Http;
use namespace Nuxed\Http\{Message, Server};

/**
 * Parses a string body with "Content-Type: multipart/form-data" into structured data.
 *
 * @link https://tools.ietf.org/html/rfc7578
 * @link https://tools.ietf.org/html/rfc2046#section-5.1.1
 */
final class MultipartParser {
  public function __construct(private Server\Options $options) {}

  public async function parse(
    Http\Message\IServerRequest $request,
  ): Awaitable<Http\Message\IServerRequest> {
    $contentType = $request->getHeaderLine('content-type');
    if (!Regex\matches($contentType, re"/boundary=\"?(.*)\"?$/")) {
      return $request;
    }

    $matches = Regex\first_match($contentType, re"/boundary=\"?(.*)\"?$/")
      as nonnull;
    $request = await $this->parseBody($request, '--'.$matches[1]);

    return $request;
  }

  private async function parseBody(
    Http\Message\IServerRequest $request,
    string $boundary,
  ): Awaitable<Http\Message\IServerRequest> {
    $len = Str\length($boundary);

    $body = $request->getBody();
    await $body->seekAsync(0);
    $start = null;
    $buffer = await Server\_Private\read_all(
      $body,
      $this->options->getChunkSize(),
      $this->options->getHttpTimeout(),
    );

    $start = Str\search($buffer, $boundary."\r\n");
    $lastOperation = async {
      return $request;
    };
    while ($start is nonnull) {
      // search following boundary (preceded by newline)
      // ignore last if not followed by boundary (SHOULD end with "--")
      $start += $len + 2;
      $end = Str\search($buffer, "\r\n".$boundary, $start);
      if ($end is nonnull) {
        // parse one part and continue searching for next
        $lastOperation = async {
          $request = await $lastOperation;
          return await $this->parsePart(
            $request,
            Str\slice($buffer, $start, $end - $start),
          );
        };
      }

      $start = $end;
    }

    return await $lastOperation;
  }

  private async function parsePart(
    Http\Message\IServerRequest $request,
    string $chunk,
  ): Awaitable<Http\Message\IServerRequest> {
    if (!Str\contains($chunk, "\r\n\r\n")) {
      return $request;
    }

    $position = Str\search($chunk, "\r\n\r\n") as nonnull;
    $headersChunk = Str\slice($chunk, 0, $position);
    $headers = $this->parseHeaders($headersChunk);
    $body = Str\slice($chunk, $position + 4);
    if (!C\contains_key($headers, 'content-disposition')) {
      return $request;
    }

    $name = $this->getParameterFromHeader(
      $headers['content-disposition'],
      'name',
    );
    if ($name is null) {
      return $request;
    }

    $filename = $this->getParameterFromHeader(
      $headers['content-disposition'],
      'filename',
    );
    if ($filename is nonnull) {
      if (!$this->options->hasFileUplaod()) {
        throw new Server\Exception\ServerException(
          Http\Message\StatusCode::BadRequest,
        );
      }

      $contentType = null;
      if (C\contains_key($headers, 'content-type')) {
        $contentType = C\first($headers['content-type']);
      }

      $request = await $this->parseFile(
        $request,
        $name,
        $filename,
        $contentType,
        $body,
      );
    } else {
      $request = await $this->parsePost($request, $name, $body);
    }

    return $request;
  }

  private async function parseFile(
    Http\Message\IServerRequest $request,
    string $name,
    string $filename,
    ?string $contentType,
    string $contents,
  ): Awaitable<Http\Message\IServerRequest> {
    $file = await $this->parseUploadedFile($filename, $contentType, $contents);

    if ($file is null) {
      return $request;
    }

    $files = dict<string, Http\Message\IUploadedFile>(
      $request->getUploadedFiles(),
    );
    if ((C\count($files) + 1) > $this->options->getUploadedFilesLimit()) {
      throw new Server\Exception\ServerException(
        Http\Message\StatusCode::PayloadTooLarge,
      );
    }

    $files[$name] = $file;

    return $request->withUploadedFiles($files);
  }

  private async function parseUploadedFile(
    string $filename,
    ?string $contentType,
    string $contents,
  ): Awaitable<Message\UploadedFile> {
    $size = Str\length($contents);
    $path = \sys_get_temp_dir().'/'.\bin2hex(\random_bytes(8));
    $file = File\open_read_write_nd($path, File\WriteMode::MUST_CREATE);

    if ($size === 0 && $filename === '') {
      await $file->closeAsync();
      return new Message\UploadedFile(
        $path,
        $size,
        Http\Message\UploadedFileError::NoFile,
        $filename,
        $contentType,
      );
    }

    if ($size > $this->options->getUploadedFileSizeLimit()) {
      await $file->closeAsync();
      return new Message\UploadedFile(
        $path,
        $size,
        Http\Message\UploadedFileError::ExceedsMaxSize,
        $filename,
        $contentType,
      );
    }

    await $file->writeAsync($contents);
    await $file->closeAsync();

    return new Message\UploadedFile(
      $path,
      $size,
      Http\Message\UploadedFileError::None,
      $filename,
      $contentType,
    );
  }

  private async function parsePost(
    Http\Message\IServerRequest $request,
    string $name,
    string $value,
  ): Awaitable<Http\Message\IServerRequest> {
    $body = $request->getParsedBody();
    $body = $body is null ? dict[] : dict<string, string>($body);
    $body[$name] = $value;

    return $request->withParsedBody($body);
  }

  private function parseHeaders(
    string $header,
  ): KeyedContainer<string, Container<string>> {
    $headers = dict[];

    foreach (Str\split(Str\trim($header), "\r\n") as $line) {
      $parts = Str\split($line, ':', 2);
      if (2 !== C\count($parts)) {
        continue;
      }

      $key = Str\lowercase(Str\trim($parts[0]));
      $values = Str\split($parts[1], ';');
      $values = Vec\map($values, (string $value): string ==> Str\trim($value));

      $headers[$key] = $values;
    }

    return $headers;
  }

  private function getParameterFromHeader(
    Container<string> $header,
    string $parameter,
  ): ?string {
    foreach ($header as $part) {
      /* HH_IGNORE_ERROR[4110] dynamic regex */
            if (!Regex\matches($part, '/'.$parameter.'="?(.*)"$/')) {
        continue;
      }

      /* HH_IGNORE_ERROR[4110] dynamic regex */
            $matches = Regex\first_match($part, '/'.$parameter.'="?(.*)"$/')
                as nonnull;
      return $matches[1];
    }

    return null;
  }

}
