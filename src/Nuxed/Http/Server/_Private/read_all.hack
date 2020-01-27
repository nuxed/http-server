namespace Nuxed\Http\Server\_Private;

use namespace HH\Lib\Experimental\IO;

async function read_all(
  IO\ReadHandle $source,
  int $chunkSize = 1048576,
  float $timeOut = 120.0,
  int $iteration = 0,
): Awaitable<string> {
  if (0 === $iteration && $source is IO\SeekableHandle) {
    await $source->seekAsync(0);
  }

  if ($source->isEndOfFile()) {
    return '';
  }

  $content = await $source->readAsync($chunkSize, $timeOut);
  $content .= await read_all($source, $chunkSize, $timeOut, $iteration + 1);

  return $content;
}
