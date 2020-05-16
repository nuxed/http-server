namespace Nuxed\Http\Server\Parser;

use namespace AzJezz\HttpNormalizer;
use namespace HH\Lib\{C, Str};
use namespace Nuxed\Contract\Http\Message;
use namespace Nuxed\Http\Server;

final class UrlEncodedParser {
  public function __construct(private Server\Options $options) {}

  public async function parse(
    Message\IServerRequest $request,
  ): Awaitable<Message\IServerRequest> {
    if (!$request->hasHeader('content-type')) {
      return $request;
    }

    $contentType = $request->getHeader('content-type');
    $contentType = Str\lowercase(C\firstx($contentType));
    if ('application/x-www-form-urlencoded' !== $contentType) {
      return $request;
    }

    $body = $request->getBody();
    $buffer = '';
    do {
      // HHAST_IGNORE_ERROR[DontAwaitInALoop]
      $chunk = await $body->readAsync(
        $this->options->getChunkSize(),
        $this->options->getHttpTimeout(),
      );
      $buffer .= $chunk;
    } while ('' !== $chunk);

    $result = HttpNormalizer\parse($buffer);

    return $request->withParsedBody($result);
  }
}
