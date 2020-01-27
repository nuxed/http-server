namespace Nuxed\Http\Server\Socket;

use namespace HH\Lib\Experimental\Network;

interface IServer {
  /**
   * Listen for client connections on the specified server address.
   */
  public static function listen(SocketAddress $address): Awaitable<IServer>;

  /**
   * Retrieve the next pending connection
   *
   * Will wait for new connection if none are pending.
   */
  public function nextConnection(): Awaitable<IConnection>;

  /**
   * Return the local (listening) address for the server
   */
  public function getLocalAddress(): SocketAddress;
}
