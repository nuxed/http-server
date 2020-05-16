namespace Nuxed\Http\Server\_Private;

use namespace HH\Lib\Str;
use namespace Nuxed\Http\Server\Socket;

/**
 * Read status line and headers from the remote client.
 */
async function read_headers(
  Socket\IConnection $connection,
  int $chunk_size = 1048576,
  int $timeout_ns = 120000,
  string $contents = '',
): Awaitable<string> {
  $chunk = await $connection->readAsync($chunk_size, $timeout_ns);
  if ('' === $chunk) {
    return $contents;
  }

  $contents .= $chunk;
  if (Str\contains($contents, "\r\n\r\n")) {
    return $contents;
  }

  return await read_headers($connection, $chunk_size, $timeout_ns, $contents);
}
