namespace Nuxed\Http\Server;

use namespace HH\Asio;
use namespace HH\Lib\{Async, Vec};
use namespace Nuxed\Contract\Http\Server;
use namespace Nuxed\Contract\Log;

final class Server {
  use Log\LoggerAwareTrait;

  private Server\IHandler $handler;
  private Server\IMiddlewareStack $stack;
  private Driver\IDriver $driver;

  private Async\Semaphore<Socket\IConnection, void> $semaphore;
  private vec<Socket\IServer> $sockets = vec[];

  private bool $running = false;

  public function __construct(
    private Options $options,
    ?Server\IHandler $handler = null,
    ?Server\IMiddlewareStack $stack = null,
    ?Driver\Driver $driver = null,
    ?Log\ILogger $logger = null,
  ) {
    $this->handler = $handler ?? new Handler\NotFoundHandler();
    $this->stack = $stack ?? new MiddlewareStack();
    $this->driver = $driver ?? new Driver\Driver($this->options);

    $this->logger = $logger;

    $this->semaphore = new Async\Semaphore(
      $options->getConnectionLimit(),
      ($connection) ==>
        $this->driver->handle($connection, $this->stack, $this->handler),
    );

    $this->stack(
      new Middleware\RequestBodyParserMiddleware(
        new Parser\MultipartParser($options),
        new Parser\UrlEncodedParser($options),
      ),
      -128,
    );
  }

  public function listen(Socket\IServer $socket): void {
    $this->sockets[] = $socket;
  }

  /**
   * Attach middleware to the stack.
   */
  public function stack(
    Server\IMiddleware $middleware,
    int $priority = 0,
  ): void {
    $this->stack->stack($middleware, $priority);
  }

  public async function run(): Awaitable<void> {
    if ($this->running) {
      throw new Exception\RuntimeException('Server is already running.');
    }

    $this->running = true;
    $servers = vec[];
    $pending = new \SplStack<Awaitable<void>>();
    foreach ($this->sockets as $socket) {
      $servers[] = async {
        while ($this->running) {
          /*HHAST_IGNORE_ERROR[DontAwaitInALoop]*/
          $connection = await $socket->nextConnection();
          $pending->push($this->semaphore->waitForAsync($connection));
        }
      };
    }

    $observe = async {
      while ($this->running) {
        if (!$pending->isEmpty()) {
          /*HHAST_IGNORE_ERROR[DontAwaitInALoop]*/
          await $pending->shift();
        } else {
          /*HHAST_IGNORE_ERROR[DontAwaitInALoop]*/
          await Asio\later();
        }
      }
    };

    await Asio\v(Vec\concat(vec[$observe], $servers));
  }

  private async function start(Socket\IServer $socket): Awaitable<void> {
    while ($this->running) {
      /*HHAST_IGNORE_ERROR[DontAwaitInALoop]*/
      $_connection = await $socket->nextConnection();
    }
  }
}
