namespace Nuxed\Http\Server\Socket;

use namespace HH\Lib\Unix;
use namespace HH\Asio;
use namespace Nuxed\Http\Server\Exception;

final class UnixServer implements IServer {
  private bool $stopped = false;

  public function __construct(private Unix\Server $server) {}

  public static async function listen(
    SocketAddress $address,
  ): Awaitable<UnixServer> {
    return new UnixServer(await Unix\Server::createAsync($address->getHost()));
  }

  /**
   * Retrieve the next pending connection
   *
   * Will wait for new connection if none are pending.
   */
  public async function nextConnection(): Awaitable<UnixConnection> {
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

    return new UnixConnection(await $incoming);
  }

  /**
   * Return the local (listening) address for the server
   */
  public function getLocalAddress(): SocketAddress {
    $socket = $this->server->getLocalAddress();
    return new SocketAddress(SocketAddressScheme::Unix, $socket);
  }

  public function stopListening(): void {
    $this->stopped = true;
    $this->server->stopListening();
  }
}
