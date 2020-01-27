namespace Nuxed\Http\Server\Middleware;

use namespace HH\Lib\Str;
use namespace Nuxed\Contract\Http\{Message, Server};

final class HostMiddlewareDecorator implements Server\IMiddleware {
  public function __construct(
    private string $host,
    private Server\IMiddleware $middleware,
  ) {}

  public async function process(
    Message\IServerRequest $request,
    Server\IHandler $handler,
  ): Awaitable<Message\IResponse> {
    $host = $request->getUri()->getHost();

    if ($host !== Str\lowercase($this->host)) {
      return await $handler->handle($request);
    }

    return await $this->middleware->process($request, $handler);
  }
}
