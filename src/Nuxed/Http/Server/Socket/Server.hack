namespace Nuxed\Http\Server\Socket;

final class Server implements IServer {
  private function __construct(private IServer $server) {}

  /**
   * Listen for client connections on the specified server address.
   */
  public static async function listen(
    SocketAddress $address,
  ): Awaitable<Server> {
    if (SocketAddressScheme::Unix === $address->getScheme()) {
      return new Server(await UnixServer::listen($address));
    }

    return new Server(await TCPServer::listen($address));
  }

  /**
   * Retrieve the next pending connection
   *
   * Will wait for new connection if none are pending.
   */
  public async function nextConnection(): Awaitable<IConnection> {
    return await $this->server->nextConnection();
  }

  /**
   * Return the local (listening) address for the server
   */
  public function getLocalAddress(): SocketAddress {
    return $this->server->getLocalAddress();
  }

  public function stopListening(): void {
    $this->server->stopListening();
  }
}
