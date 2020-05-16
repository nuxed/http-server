namespace Nuxed\Http\Server\Socket;

use namespace HH\Lib\Network;

abstract class AbstractConnection<T as Network\CloseableSocket>
  implements IConnection {

  private ?int $id = null;

  public function __construct(protected T $socket) {}

  /** An immediate, unordered read.
   *
   * @see `genRead`
   * @param max_bytes the maximum number of bytes to read
   *   - if `null`, an internal default will be used.
   *   - if 0, an `InvalidArgumentException` will be raised.
   * @throws `OS\BlockingIOException` if there is no more
   *   data available to read. If you want to wait for more
   *   data, use `genRead` instead.
   * @returns
   *   - the read data on success.
   *   - the empty string if the end of file is reached.
   */
  public function read(?int $max_bytes = null): string {
    return $this->socket->read($max_bytes);
  }

  /** Read from the handle, waiting for data if necessary.
   *
   * A wrapper around `read()` that will wait for more data if there is none
   * available at present.
   *
   * @param max_bytes the maximum number of bytes to read
   *   - if `null`, an internal default will be used.
   *   - if 0, an `InvalidArgumentException` will be raised.
   * @returns
   *   - the read data on success
   *   - the empty string if the end of file is reached.
   */
  public async function readAsync(
    ?int $max_bytes = null,
    ?int $timeout_ns = null,
  ): Awaitable<string> {
    return await $this->socket->readAsync($max_bytes, $timeout_ns);
  }

  /** An immediate unordered write.
   *
   * @see `genWrite()`
   * @throws `OS\BlockingIOException` if the handle is a socket or similar,
   *   and the write would block.
   * @returns the number of bytes written on success
   *
   * Returns the number of bytes written, which may be 0.
   */
  public function write(string $bytes): int {
    return $this->socket->write($bytes);
  }

  /** Write data, waiting if necessary.
   *
   * A wrapper around `write()` that will wait if `write()` would throw
   * an `OS\BlockingIOException`
   *
   * It is possible for the write to *partially* succeed - check the return
   * value and call again if needed.
   *
   * @returns the number of bytes written, which may be less than the length of
   *   input string.
   */
  public async function writeAsync(
    string $bytes,
    ?int $timeout_ns = null,
  ): Awaitable<int> {
    return await $this->socket->writeAsync($bytes, $timeout_ns);
  }

  public async function flushAsync(): Awaitable<void> {
    await $this->socket->flushAsync();
  }

  /**
   * Returns the address of the local side of the socket
   */
  abstract public function getLocalAddress(): SocketAddress;

  /**
   * Returns the address of the remote side of the socket
   */
  abstract public function getRemoteAddress(): SocketAddress;

  /** Complete pending operations then close the handle */
  final public async function closeAsync(): Awaitable<void> {
    await $this->socket->closeAsync();
  }
}
