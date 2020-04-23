namespace Nuxed\Http\Server\Socket;

use namespace HH\Lib\Unix;

final class UnixConnection extends AbstractConnection<Unix\CloseableSocket> {
  /**
   * Returns the address of the local side of the socket
   */
  <<__Override>>
  public function getLocalAddress(): SocketAddress {
    $address = $this->socket->getLocalAddress();
    return new SocketAddress(SocketAddressScheme::Unix, $address[0]);
  }

  /**
   * Returns the address of the remote side of the socket
   */
  <<__Override>>
  public function getRemoteAddress(): SocketAddress {
    $address = $this->socket->getPeerAddress();
    return new SocketAddress(SocketAddressScheme::Unix, $address[0]);
  }
}
