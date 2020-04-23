namespace Nuxed\Http\Server\_Private;

use namespace HH\Lib\Str;
use namespace Nuxed\Http\Server\Socket;

async function read_body(
  Socket\IConnection $connection,
  int $chunkSize = 1048576,
  float $timeOut = 120.0,
  ?int $limit = null,
  string $contents = '',
): Awaitable<string> {
  // ?
  if ($connection->isEndOfFile()) {
    return $contents;
  }

  if ($limit is nonnull && Str\length($contents) >= $limit) {
    return $contents;
  }

  // sadly, there's some issues with socket connections currently :
  // - when `$timeout_seconds` is provided, it blocks
  // - `isEndOfFile` always returns false
  // both these issues makes it impossible to use `readAsync` / `readLineAsync`
  // in here, issues have been reported to Facebook.
  $chunk = $connection->rawReadBlocking($chunkSize);
  if ('' === $chunk) {
    return $contents;
  }

  $contents .= $chunk;

  return await read_body($connection, $chunkSize, $timeOut, $limit, $contents);
}
