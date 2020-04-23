namespace Nuxed\Http\Server\Socket;

use namespace HH\Lib\TCP;

final class TCPConnection extends AbstractConnection<TCP\CloseableSocket> {
  /**
   * Returns the address of the local side of the socket
   */
  <<__Override>>
  public function getLocalAddress(): SocketAddress {
    $address = $this->socket->getLocalAddress();
    return new SocketAddress(
      SocketAddressScheme::TCP,
      $address[0],
      $address[1],
    );
  }

  /**
   * Returns the address of the remote side of the socket
   */
  <<__Override>>
  public function getRemoteAddress(): SocketAddress {
    $address = $this->socket->getPeerAddress();
    return new SocketAddress(
      SocketAddressScheme::TCP,
      $address[0],
      $address[1],
    );
  }
}
