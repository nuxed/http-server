namespace Nuxed\Http\Server\Socket;

use namespace HH\Lib\Str;

final class SocketAddress {
  private SocketAddressScheme $scheme;
  private string $host;
  private ?int $port;

  public function __construct(
    SocketAddressScheme $scheme,
    string $host,
    ?int $port = null,
  ) {
    invariant(
      $port is null || ($port >= 0 && $port < 65535),
      'Port number must be null or an integer between 1 and 65535',
    );

    if (Str\contains($host, ':')) {
      $host = Str\trim($host, '[]');
    }

    $this->scheme = $scheme;
    $this->host = $host;
    $this->port = $port;
  }

  /**
   * Create a server address.
   *
   * @param string $uri URI in scheme://host:port format. TCP is assumed if no scheme is present.
   */
  public static function create(string $uri): SocketAddress {
    if (Str\starts_with($uri, 'unix://')) {
      return new SocketAddress(
        SocketAddressScheme::Unix,
        Str\strip_prefix($uri, 'unix://'),
      );
    }

    if (Str\starts_with($uri, 'tcp://')) {
      $uri = Str\strip_prefix($uri, 'tcp://');
    }

    $scheme = SocketAddressScheme::TCP;
    $position = Str\search_last($uri, ':');
    if ($position is nonnull) {
      $host = Str\slice($uri, 0, $position);
      $port = Str\to_int(Str\slice($uri, $position + 1));

      return new SocketAddress($scheme, $host, $port);
    }

    return new SocketAddress($scheme, $uri);
  }

  public function getScheme(): SocketAddressScheme {
    return $this->scheme;
  }

  public function withScheme(SocketAddressScheme $scheme): SocketAddress {
    $address = clone $this;
    $address->scheme = $scheme;

    return $address;
  }

  public function getHost(): string {
    return $this->host;
  }

  public function withHost(string $host): SocketAddress {
    $address = clone $this;
    $address->host = $host;

    return $address;
  }

  public function getPort(): ?int {
    return $this->port;
  }

  public function withPort(?int $port): SocketAddress {
    $address = clone $this;
    $address->port = $port;

    return $address;
  }

  /**
   * @return string scheme://host:port formatted string.
   */
  public function toString(): string {
    $host = $this->host;

    if (Str\contains($host, ':')) {
      $host = '['.$host.']';
    }

    if ($this->port === null) {
      return $host;
    }

    return Str\format('%s://%s:%d', $this->scheme, $host, $this->port);
  }
}
