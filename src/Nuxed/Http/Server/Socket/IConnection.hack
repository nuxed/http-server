namespace Nuxed\Http\Server\Socket;

use namespace HH\Lib\IO;

interface IConnection extends IO\CloseableReadWriteHandle {
  /**
   * Returns the address of the local side of the socket
   */
  public function getLocalAddress(): SocketAddress;

  /**
   * Returns the address of the remote side of the socket
   */
  public function getRemoteAddress(): SocketAddress;
}
