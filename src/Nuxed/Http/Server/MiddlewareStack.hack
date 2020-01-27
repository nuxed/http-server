namespace Nuxed\Http\Server;

use namespace Nuxed\Contract\Http\{Message, Server};

final class MiddlewareStack implements Server\IMiddlewareStack {
  private \SplPriorityQueue<Server\IMiddleware> $stack;

  public function __construct() {
    $this->stack = new \SplPriorityQueue<Server\IMiddleware>();
  }

  public function __clone(): void {
    $this->stack = clone $this->stack;
  }

  /**
   * Attach middleware to the stack.
   */
  public function stack(
    Server\IMiddleware $middleware,
    int $priority = 0,
  ): void {
    $this->stack->insert($middleware, $priority);
  }

  /**
   * Middleware invocation.
   *
   * Executes the internal stack, passing $handler as the "final
   * handler" in cases when the stack exhausts itself.
   */
  public async function process(
    Message\IServerRequest $request,
    Server\IHandler $handler,
  ): Awaitable<Message\IResponse> {
    $next = new Handler\NextMiddlewareHandler($this->stack, $handler);
    return await $next->handle($request);
  }
}
