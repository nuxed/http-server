namespace Nuxed\Http\Server\_Private;

use namespace HH\Lib\Str;
use namespace Nuxed\Http\Server\Socket;

async function read_body(
  Socket\IConnection $connection,
  int $chunk_size = 1048576,
  int $timeout_ns = 12000,
  ?int $limit = null,
  string $contents = '',
): Awaitable<string> {
  if ($limit is nonnull && Str\length($contents) >= $limit) {
    return $contents;
  }

  // sadly, there's some issues with socket connections currently :
  // - when `$timeout_seconds` is provided, it blocks
  // - `isEndOfFile` always returns false
  // both these issues makes it impossible to use `readAsync` / `readLineAsync`
  // in here, issues have been reported to Facebook.
  $chunk = await $connection->readAsync($chunk_size, $timeout_ns);
  if ('' === $chunk) {
    return $contents;
  }

  $contents .= $chunk;

  return await read_body(
    $connection,
    $chunk_size,
    $timeout_ns,
    $limit,
    $contents,
  );
}
