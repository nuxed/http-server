namespace Nuxed\Http\Server\Socket;

use namespace HH\Asio;
use namespace HH\Lib\Async;
use namespace HH\Lib\Experimental\{IO, Network};

abstract class AbstractConnection<T as Network\CloseableSocket>
  implements IConnection {
  private ?int $id = null;

  public function __construct(protected T $socket) {}

  /** An immediate, unordered blocking read.
    *
    * You almost certainly don't want to call this; instead, use
    * `readAsync()` or `readLineAsync()`, which are wrappers around
    * this
    */
  final public function rawReadBlocking(?int $max_bytes = null): string {
    return $this->socket->rawReadBlocking($max_bytes);
  }

  /** Read until we reach `$max_bytes`, or the end of the file. */
  final public async function readAsync(
    ?int $max_bytes = null,
    ?float $timeout_seconds = null,
  ): Awaitable<string> {
    return await $this->socket->readAsync($max_bytes, $timeout_seconds);
  }

  /** Read until we reach `$max_bytes`, the end of the file, or the
   * end of the line.
   *
   * 'End of line' is platform-specific, and matches the C `fgets()`
   * function; the newline character/characters are included in the
   * return value. */
  final public async function readLineAsync(
    ?int $max_bytes = null,
    ?float $timeout_seconds = null,
  ): Awaitable<string> {
    return await $this->socket->readLineAsync($max_bytes, $timeout_seconds);
  }

  /** Possibly write some of the string.
   *
   * Returns the number of bytes written, which may be 0.
   */
  final public function rawWriteBlocking(string $bytes): int {
    return $this->rawWriteBlocking($bytes);
  }

  final public async function writeAsync(
    string $bytes,
    ?float $timeout_seconds = null,
  ): Awaitable<void> {
    await $this->socket->writeAsync($bytes, $timeout_seconds);
  }

  final public async function flushAsync(): Awaitable<void> {
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

  final public function isEndOfFile(): bool {
    return $this->socket->isEndOfFile();
  }

  /** Complete pending operations then close the handle */
  final public async function closeAsync(): Awaitable<void> {
    await $this->socket->closeAsync();
  }
}
