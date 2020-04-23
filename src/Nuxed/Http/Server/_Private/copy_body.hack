namespace Nuxed\Http\Server\_Private;

use namespace HH\Lib\{IO, Str};

async function copy_body(
  <<__AcceptDisposable>> IO\ReadHandle $source,
  <<__AcceptDisposable>> IO\WriteHandle $target,
  ?int $limit,
  int $chunkSize = 1048576,
  float $timeOut = 120.0,
  int $length = 0,
): Awaitable<void> {
  $content = '';
  if (!$source->isEndOfFile()) {
    $content = $source->rawReadBlocking($chunkSize);
    $length += Str\length($content);
    if ($limit is nonnull && $length > $limit) {
      $remaining = $length - $limit;
      $content = Str\slice($content, 0, Str\length($content) - $remaining);
      await $target->writeAsync($content, $timeOut);
      return;
    }

    await $target->writeAsync($content, $timeOut);

    if ($length === $limit) {
      return;
    }
  }

  if ('' !== $content && !$source->isEndOfFile()) {
    await copy_body($source, $target, $limit, $chunkSize, $timeOut, $length);
  }
}
