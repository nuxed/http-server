namespace Nuxed\Http\Server\_Private;

use namespace HH\Lib\Str;
use namespace Nuxed\Http\Server\Socket;

/**
 * Read status line and headers from the remote client.
 */
async function read_headers(
  Socket\IConnection $connection,
  int $chunkSize = 1048576,
  float $timeOut = 120.0,
  string $contents = '',
): Awaitable<string> {
  // ?
  if ($connection->isEndOfFile()) {
    return $contents;
  }

  $contents .= await $connection->readLineAsync($chunkSize, $timeOut);
  if (Str\ends_with($contents, "\r\n\r\n")) {
    return $contents;
  }

  return await read_headers($connection, $chunkSize, $timeOut, $contents);
}
