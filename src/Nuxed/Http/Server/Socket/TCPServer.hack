namespace Nuxed\Http\Server\Socket;

use namespace HH\Lib\{PseudoRandom, Str};
use namespace HH\Lib\Experimental\{Network, TCP};

final class TCPServer implements IServer {
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
      ),
    );
  }

  /**
   * Retrieve the next pending connection
   *
   * Will wait for new connection if none are pending.
   */
  public async function nextConnection(): Awaitable<TCPConnection> {
    return new TCPConnection(await $this->server->nextConnectionNDAsync());
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
}
