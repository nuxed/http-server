namespace Nuxed\Http\Server\Handler;

use namespace Nuxed\Contract\Http\{Message, Server};

final class StackHandler implements Server\IHandler {
  public function __construct(
    private Server\IMiddleware $middleware,
    private Server\IHandler $handler,
  ) {}

  public async function handle(
    Message\IServerRequest $request,
  ): Awaitable<Message\IResponse> {
    return await $this->middleware->process($request, $this->handler);
  }
}
