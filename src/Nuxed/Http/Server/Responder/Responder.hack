namespace Nuxed\Http\Server\Responder;

use namespace Nuxed\Contract\Http\Message;
use namespace Nuxed\Http\Server\{Exception, Socket};
use namespace Nuxed\Http\Server;
use namespace HH\Lib\{C, OS, Str};

final class Responder implements IResponder {

  public function __construct(private Server\Options $options) {
  }

  /**
   * Respond to the client connection with the given response.
   *
   * The response should be filtered and prepared using the given request,
   * before being sent back to the client.
   */
  public async function respond(
    Socket\IConnection $connection,
    Message\IResponse $response,
    ?Message\IServerRequest $request = null,
  ): Awaitable<void> {
    $shouldClose = false;

    $response = $this->filter($response, $request);
    $response = $this->addSetCookieHeader($response);
    if (
      $this->options->hasXPoweredBy() && !$response->hasHeader('X-Powered-By')
    ) {
      $response = $response->withHeader('X-Powered-By', vec[
        'Nuxed',
        'HHVM '.\HHVM_VERSION,
      ]);
    }

    $chunked = !$response->hasHeader('content-length') &&
      $response->getProtocolVersion() === '1.1' &&
      $response->getStatusCode() >= Message\StatusCode::Ok;

    foreach ($response->getHeader('connection') as $value) {
      if ('close' === Str\lowercase($value)) {
        $chunked = false;
        $shouldClose = true;
      }
    }

    if ($chunked) {
      $response = $response->withHeader('transfer-encoding', vec['chunked']);
    }

    $buffer = Str\format(
      "HTTP/%s %d %s\r\n",
      $response->getProtocolVersion(),
      $response->getStatusCode(),
      $response->getReasonPhrase() ?? '',
    );
    $buffer .= $this->formatHeaders($response);
    $buffer .= "\r\n";

    if (
      $request is nonnull && 'HEAD' === Str\uppercase($request->getMethod())
    ) {
      await $connection->writeAsync($buffer, $this->options->getHttpTimeout());
      if ($shouldClose) {
        await $connection->closeAsync();
      }
      return;
    }


    // Required for the finally, not directly overwritten, even if your IDE says otherwise.
    $chunk = '';
    $body = $response->getBody();
    await $body->seekAsync(0);

    $streamThreshold = $this->options->getStreamThreshold();
    try {
      $readHandle = $body->readAsync($this->options->getChunkSize());

      while (true) {
        $flash = false;
        try {
          if ($buffer !== '') {
            // HHAST_IGNORE_ERROR[DontAwaitInALoop]
            $chunk = await Server\_Private\timeout($readHandle, 0.1);
          } else {
            // HHAST_IGNORE_ERROR[DontAwaitInALoop]
            $chunk = await $readHandle;
          }

          if ('' === $chunk) {
            break;
          }

          $readHandle = $body->readAsync($this->options->getChunkSize());
        } catch (OS\TimeoutError $e) {
          $flash = true;
        }

        if (!$flash) {
          $length = Str\length($chunk);

          if ($chunked) {
            $chunk = Str\format("%x\r\n%s\r\n", $length, $chunk);
          }

          $buffer .= $chunk;

          if (Str\length($buffer) < $streamThreshold) {
            continue;
          }
        }

        // Initially the buffer won't be empty and contains the headers.
        // We save a separate write or the headers here.
        $handle = $connection->writeAsync(
          $buffer,
          $this->options->getHttpTimeout(),
        );

        $buffer = '';
        $chunk = ''; // Don't use null here, because of the finally

        // HHAST_IGNORE_ERROR[DontAwaitInALoop]
        await $handle;
      }

      if ($chunked) {
        $buffer .= "0\r\n\r\n";
      }

      if ('' !== $buffer || $shouldClose) {
        await $connection->writeAsync($buffer);
        if ($shouldClose) {
          await $connection->closeAsync();
        }
      }
    } catch (Exception\ServerException $e) {
      return; // Client will be closed in finally.
    } finally {
      if ($chunk is nonnull) {
        await $connection->closeAsync();
      }
    }
  }

  /**
   * Filters and updates response headers based on protocol and connection header from the request.
   */
  private function filter(
    Message\IResponse $response,
    ?Message\IServerRequest $request = null,
  ): Message\IResponse {
    if ($response->getStatusCode() < Message\StatusCode::Ok) {
      return $response->withoutHeader(
        'content-length',
      ); // 1xx responses do not have a body.
    }

    $contentLength = C\first($response->getHeader('content-length'));
    $shouldClose = (
      $request is nonnull &&
      C\contains($request->getHeader('connection'), 'close')
    ) ||
      (
        $response->hasHeader('connection') &&
        C\contains($response->getHeader('connection'), 'close')
      );


    if ($contentLength !== null) {
      $shouldClose = $shouldClose || $response->getProtocolVersion() === '1.0';

      $response = $response->withoutHeader('transfer-encoding');
    } else if ($response->getProtocolVersion() === '1.1') {
      $response = $response->withoutHeader('content-length');
    } else {
      $shouldClose = true;
    }

    if ($shouldClose) {
      $response = $response->withHeader('connection', vec['close']);
    } else {
      $response = $response
        ->withHeader('connection', vec['keep-alive'])
        ->withHeader(
          'keep-alive',
          vec['timeout='.$this->options->getHttpTimeout()],
        );
    }

    return $response->withHeader('date', vec[
      Server\_Private\format_date_header(),
    ]);
  }

  public function addSetCookieHeader(
    Message\IResponse $response,
  ): Message\IResponse {
    $values = vec[];
    foreach ($response->getCookies() as $name => $cookie) {
      $values[] = $this->formatCookieHeader($name, $cookie);
    }

    if (0 === C\count($values)) {
      return $response;
    }

    return $response->withAddedHeader('Set-Cookie', $values);
  }

  /**
   * @see https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie
   */
  private function formatCookieHeader(
    string $name,
    Message\ICookie $cookie,
  ): string {
    $cookieStringParts = vec[
      \urlencode($name).'='.\urlencode($cookie->getValue()),
    ];

    /**
     * __Host- prefix : Cookies with names starting with __Host- must not
     * have a domain specified (and therefore aren't sent to subdomains)
     * and the path must be /.
     */
    $hostOnly = Str\starts_with($name, '__Host-');
    $domain = $cookie->getDomain();
    if ($domain is nonnull && !$hostOnly) {
      $cookieStringParts[] = Str\format('Domain=%s', $domain);
    }

    $path = $cookie->getPath();
    if ($path is nonnull && !$hostOnly) {
      $cookieStringParts[] = Str\format('Path=%s', $path);
    } else if ($hostOnly) {
      $cookieStringParts[] = 'Path=/';
    }

    /*
     * If both Expires and Max-Age are set, Max-Age has precedence.
     */
    $expires = $cookie->getExpires();
    $maxAge = $cookie->getMaxAge();
    if ($maxAge is nonnull) {
      $cookieStringParts[] = Str\format(
        'MaxAge=%s',
        \date('D, d M Y H:i:s T', $maxAge),
      );
    } else if ($expires is nonnull) {
      $cookieStringParts[] = Str\format(
        'Expires=%s',
        \date('D, d M Y H:i:s T', $expires),
      );
    }

    /*
     * __Host- prefix : Cookies with names starting with __Host- must be set
     * with the secure flag, must be from a secure page (HTTPS)
     *
     * __Secure- prefix : Cookies names starting with __Secure- must be set
     * with the secure flag from a secure page (HTTPS).
     */
    if (
      $cookie->getSecure() || Str\starts_with($name, '__Secure-') || $hostOnly
    ) {
      $cookieStringParts[] = 'Secure';
    }

    if ($cookie->getHttpOnly()) {
      $cookieStringParts[] = 'HttpOnly';
    }

    $sameSite = $cookie->getSameSite();
    if ($sameSite is nonnull) {
      $cookieStringParts[] = Str\format('SameSite=%s', $sameSite as string);
    }

    return Str\join($cookieStringParts, '; ');
  }

  private function formatHeaders(Message\IResponse $response): string {
    $buffer = '';

    foreach ($response->getHeaders() as $name => $values) {
      // Ignore any HTTP/2 pseudo headers
      if (Str\starts_with($name, ':')) {
        continue;
      }

      foreach ($values as $value) {
        $buffer .= Str\format("%s: %s\r\n", $name, $value);
      }
    }

    return $buffer;
  }
}
