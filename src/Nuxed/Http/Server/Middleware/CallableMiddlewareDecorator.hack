namespace Nuxed\Http\Server\Middleware;

use namespace Nuxed\Contract\Http\{Message, Server};

final class CallableMiddlewareDecorator implements Server\IMiddleware {
  public function __construct(private CallableMiddleware $middleware) {}

  public function process(
    Message\IServerRequest $request,
    Server\IHandler $handler,
  ): Awaitable<Message\IResponse> {
    $fun = $this->middleware;
    return $fun($request, $handler);
  }
}
