namespace Nuxed\Http\Server\_Private;

use namespace HH\Lib\{Async, OS};

async function timeout<T>(Awaitable<T> $task, float $seconds): Awaitable<T> {
  $usecs = (int)(1000000 * $seconds);
  $poll = Async\KeyedPoll::create();
  $poll->add('sleep', SleepWaitHandle::create($usecs));
  $poll->add('task', $task);

  foreach ($poll await as $key => $value) {
    if ($key === 'sleep') {
      throw new OS\TimeoutError('Task timeout.');
    } else {
      /* HH_IGNORE_ERROR[4110] */
      return $value;
    }
  }

  return await $task;
}
