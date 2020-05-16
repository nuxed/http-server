namespace Nuxed\Http\Server\Socket;

use namespace HH\Asio;
use namespace HH\Lib\{Network, Str, TCP};
use namespace Nuxed\Http\Server\Exception;

final class TCPServer implements IServer {
  private bool $stopped = false;

  public function __construct(private TCP\Server $server) {}

  /**
   * Listen for client connections on the specified server address.
   */
  public static async function listen(
    SocketAddress $address,
  ): Awaitable<TCPServer> {
    if ($address->getPort() is null) {
      $address = $address->withPort(0);
    }

    return new TCPServer(
      await TCP\Server::createAsync(
        Str\contains($address->getHost(), ':')
          ? Network\IPProtocolVersion::IPV6
          : Network\IPProtocolVersion::IPV4,
        $address->getHost(),
        $address->getPort() as nonnull,
        shape(
          'socket_options' => shape(
            'SO_REUSEADDR' => true,
          ),
        ),
      ),
    );
  }
  /**
   * Retrieve the next pending connection
   *
   * Will wait for new connection if none are pending.
   */
  public async function nextConnection(): Awaitable<TCPConnection> {
    $incoming = $this->server->nextConnectionNDAsync();
    while (!Asio\has_finished($incoming)) {
      // HHAST_IGNORE_ERROR[DontAwaitInALoop] Its meant to await in loop.
      await Asio\later();
      if ($this->stopped) {
        throw new Exception\RuntimeException(
          'Server has shutdown while listening to incoming connection.',
        );
      }
    }

    return new TCPConnection(await $incoming);
  }

  /**
   * Return the local (listening) address for the server
   */
  public function getLocalAddress(): SocketAddress {
    $address = $this->server->getLocalAddress();
    return new SocketAddress(
      SocketAddressScheme::TCP,
      $address[0],
      $address[1],
    );
  }

  public function stopListening(): void {
    $this->stopped = true;
    $this->server->stopListening();
  }
}
