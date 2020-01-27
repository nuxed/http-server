namespace Nuxed\Http\Server\Parser;

use namespace HH\Lib\{C, Str, Regex, Vec};
use namespace Nuxed\Http\Server\Socket;
use namespace Nuxed\Http\{Server, Message};
use namespace Nuxed\Contract\{Log, Http};

final class Parser implements IParser {
  public function __construct(private Server\Options $options) {}

  public async function parse(
    Socket\IConnection $connection,
  ): Awaitable<Http\Message\IServerRequest> {
    $buffer = await Server\_Private\read_headers($connection);
    $endOfHeader = Str\search($buffer, "\r\n\r\n");

    $limit = $this->options->getHeaderSizeLimit();
    if (
      ($endOfHeader is nonnull && $endOfHeader > $limit) ||
      ($endOfHeader is null && Str\length($buffer) > $limit)
    ) {
      throw new Server\Exception\ServerException(
        Http\Message\StatusCode::RequestHeaderFieldsTooLarge,
      );
    }

    if ($endOfHeader is null) {

      throw new Server\Exception\ServerException(
        Http\Message\StatusCode::BadRequest,
      );
    }

    $request = await $this->parseRequest(
      Str\slice($buffer, 0, $endOfHeader + 2),
      $connection->getRemoteAddress(),
      $connection->getLocalAddress(),
    );


    $contentLength = 0;
    if ($request->hasHeader('Transfer-Encoding')) {
      $contentLength = null;
    } elseif ($request->hasHeader('Content-Length')) {
      $contentLength = Str\to_int($request->getHeaderLine('Content-Length'));
    }

    if ($contentLength === 0) {
      // happy path: request body is known to be empty
      $stream = Message\Body\memory();
    } else {
      // otherwise body is present => delimit using Content-Length
      $body = Server\_Private\read_body(
        $connection,
        $this->options->getChunkSize(),
        $this->options->getHttpTimeout(),
        $contentLength,
      );
      $stream = Message\Body\temporary();
      await Server\_Private\copy_body(
        $connection,
        $stream,
        $contentLength,
        $this->options->getChunkSize(),
        $this->options->getHttpTimeout(),
      );
    }

    return $request->withBody($stream);
  }

  private async function parseRequest(
    string $headers,
    Socket\SocketAddress $remoteSocketUri,
    Socket\SocketAddress $localSocketUri,
  ): Awaitable<Http\Message\IServerRequest> {
    // additional, stricter safe-guard for request line
    // because request parser doesn't properly cope with invalid ones
    $eol = Str\search($headers, "\r\n") as nonnull;
    $start = Str\slice($headers, 0, $eol);
    $headers = Str\slice($headers, $eol + 2);
    if (!Regex\matches($start, re"/^([A-Z]+) (\S+) HTTP\/(\d+(?:\.\d+)?)$/i")) {
      throw new Server\Exception\ServerException(
        Http\Message\StatusCode::BadRequest,
      );
    }

    $request = Regex\first_match(
      $start,
      re"/^([A-Z]+) (\S+) HTTP\/(\d+(?:\.\d+)?)$/i",
    ) as nonnull;
    $method = $request[1];
    $target = $request[2];
    $version = $request[3];

    // only support HTTP/1.1 and HTTP/1.0 requests
    if ('1.1' !== $version && '1.0' !== $version) {
      throw new Server\Exception\ServerException(
        Http\Message\StatusCode::NotImplemented,
      );
    }

    $regex =
      re"/^([^()<>@,;:\\\"\/\[\]?={}\x01-\x20\x7F]++):[\x20\x09]*+((?:[\x20\x09]*+[\x21-\x7E\x80-\xFF]++)*+)[\x20\x09]*+[\r]?+\n/m";
    $matches = Regex\every_match($headers, $regex);
    // check number of valid header fields matches number of lines + request line
    $n = 0;
    $i = 0;
    while (true) {
      $p = Str\search($headers, "\n", $i);
      if ($p is nonnull) {
        $i = $p + 1;
        $n++;
      } else {
        break;
      }
    }
    if ($n !== C\count($matches)) {
      throw new Server\Exception\ServerException(
        Http\Message\StatusCode::BadRequest,
      );
    }

    // format all header fields
    $host = null;
    $fields = dict[];
    foreach ($matches as $match) {
      $key = $match[1];
      $value = $match[2];
      if (C\contains_key($fields, $key)) {
        $fields[$key][] = $value;
      } else {
        $fields[$key] = vec[$value];
      }

      // match `Host` request header
      if ($host is null && 'host' === Str\lowercase($key)) {
        $host = $value;
      }
    }

    // create new obj implementing ServerRequestInterface by preserving all
    // previous properties and restoring original request-target
    $serverParams = dict[
      'REQUEST_TIME' => (string)\time(),
      'REQUEST_TIME_FLOAT' => (string)\microtime(true),
    ];

    $scheme = 'http://';
    // default host if unset comes from local socket address or defaults to localhost
    if ($host === null) {
      $host = $localSocketUri->getHost();
      $port = $localSocketUri->getPort();
      if ($port is nonnull) {
        $host = Str\format('%s:%d', $host, $port);
      } else {
        // unix
        $host = '127.0.0.1';
      }
    }

    if ($method === 'OPTIONS' && $target === '*') {
      // support asterisk-form for `OPTIONS *` request line only
      $uri = $scheme.$host;
    } elseif ($method === 'CONNECT') {
      $parts = \parse_url('tcp://'.$target);

      // check this is a valid authority-form request-target (host:port)
      if (
        !C\contains_key($parts, 'scheme') ||
        !C\contains_key($parts, 'host') ||
        !C\contains_key($parts, 'port') ||
        C\count($parts) !== 3
      ) {
        // CONNECT method MUST use authority-form request target
        throw new Server\Exception\ServerException(
          Http\Message\StatusCode::BadRequest,
        );
      }

      $uri = $scheme.$target;
    } else {
      if (Str\starts_with($target, '/')) {
        $uri = $scheme.$host.$target;
      } else {
        // ensure absolute-form request-target contains a valid URI
        $parts = \parse_url($target);

        // make sure value contains valid host component (IP or hostname), but no fragment
        if (
          !C\contains_key($parts, 'scheme') ||
          !C\contains_key($parts, 'host') ||
          $parts['scheme'] !== 'http' ||
          !C\contains_key($parts, 'fragment')
        ) {
          // Invalid absolute-form request-target
          throw new Server\Exception\ServerException(
            Http\Message\StatusCode::BadRequest,
          );
        }

        $uri = $target;
      }
    }
    $uri = Message\uri($uri);

    // apply REMOTE_ADDR and REMOTE_PORT if source address is known
    // address should always be known, unless this is over Unix domain sockets (UDS)
    if ($remoteSocketUri->getPort() is nonnull) {
      $serverParams['REMOTE_ADDR'] = $remoteSocketUri->getHost();
      $serverParams['REMOTE_PORT'] = (string)$remoteSocketUri->getPort();
    }

    // apply SERVER_ADDR and SERVER_PORT if server address is known
    // address should always be known, even for Unix domain sockets (UDS)
    // but skip UDS as it doesn't have a concept of host/port.
    if ($localSocketUri->getPort() is nonnull) {
      $serverParams['SERVER_ADDR'] = $localSocketUri->getHost();
      $serverParams['SERVER_PORT'] = (string)$localSocketUri->getPort();
    }

    $request = new Message\ServerRequest(
      $method,
      $uri,
      $fields,
      null,
      $version,
      $serverParams,
    );

    // only assign request target if it is not in origin-form (happy path for most normal requests)
    if (!Str\starts_with($target, '/')) {
      $request = $request->withRequestTarget($target);
    }

    // Optional Host header value MUST be valid (host and optional port)
    if ($request->hasHeader('host')) {
      try {
        $host = Message\uri('http://'.$request->getHeaderLine('Host'));
      } catch (Message\Exception\InvalidArgumentException $e) {
        // Invalid Host header
        $exception = new Server\Exception\ServerException(
          Http\Message\StatusCode::BadRequest,
        );
        $exception->setPrevious($e);

        throw $exception;
      }

      // make sure value contains valid host component (IP or hostname)
      if ($host->getScheme() is null || $host->getHost() is null) {
        throw new Server\Exception\ServerException(
          Http\Message\StatusCode::BadRequest,
        );
      }

      // make sure value does not contain any other URI component
      $host = $host->withScheme(null)->withHost(null)->withPort(null);
      if ('' !== $host->toString()) {
        throw new Server\Exception\ServerException(
          Http\Message\StatusCode::BadRequest,
        );
      }
    }

    // ensure message boundaries are valid according to Content-Length and Transfer-Encoding request headers
    if ($request->hasHeader('Transfer-Encoding')) {
      if (
        Str\lowercase($request->getHeaderLine('Transfer-Encoding')) !==
          'chunked'
      ) {
        throw new Server\Exception\ServerException(
          Http\Message\StatusCode::NotImplemented,
        );
      }

      // Transfer-Encoding: chunked and Content-Length header MUST NOT be used at the same time
      // as per https://tools.ietf.org/html/rfc7230#section-3.3.3
      if ($request->hasHeader('Content-Length')) {
        throw new Server\Exception\ServerException(
          Http\Message\StatusCode::BadRequest,
        );
      }
    } elseif ($request->hasHeader('Content-Length')) {
      $string = $request->getHeaderLine('Content-Length');
      $int = Str\to_int($string);
      if ($int is null) {
        // Content-Length value is not an integer or not a single integer
        throw new Server\Exception\ServerException(
          Http\Message\StatusCode::BadRequest,
        );
      }
    }

    // always sanitize Host header because it contains critical routing information
    $request = $request->withUri(clone $request->getUri());

    return $request;
  }
}
