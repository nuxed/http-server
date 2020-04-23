namespace Nuxed\Http\Server\Socket;

use namespace HH\Lib\Unix;

final class UnixServer implements IServer {
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
    return new UnixConnection(await $this->server->nextConnectionNDAsync());
  }

  /**
   * Return the local (listening) address for the server
   */
  public function getLocalAddress(): SocketAddress {
    $socket = $this->server->getLocalAddress();
    return new SocketAddress(SocketAddressScheme::Unix, $socket);
  }
}
