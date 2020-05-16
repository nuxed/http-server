namespace Nuxed\Http\Server\_Private;

use namespace HH\Lib\{IO, Str};

async function copy_body(
  IO\ReadHandle $source,
  IO\WriteHandle $target,
  ?int $limit,
  int $chunk_size = 1048576,
  int $timeout_ns = 120000,
  int $length = 0,
): Awaitable<void> {
  $chunk = await $source->readAsync($chunk_size, $timeout_ns);
  $length += Str\length($chunk);
  if ($limit is nonnull && $length > $limit) {
    $remaining = $length - $limit;
    $chunk = Str\slice($chunk, 0, Str\length($chunk) - $remaining);
    await $target->writeAsync($chunk, $timeout_ns);
    return;
  }

  if ('' !== $chunk) {
    await $target->writeAsync($chunk, $timeout_ns);

    if ($length === $limit) {
      return;
    }

    await copy_body(
      $source,
      $target,
      $limit,
      $chunk_size,
      $timeout_ns,
      $length,
    );
  }
}
