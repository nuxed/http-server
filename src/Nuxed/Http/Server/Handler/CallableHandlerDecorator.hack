namespace Nuxed\Http\Server\Handler;

use namespace Nuxed\Contract\Http\{Message, Server};

final class CallableHandlerDecorator implements Server\IHandler {
  public function __construct(private CallableHandler $callback) {}

  public function handle(
    Message\IServerRequest $request,
  ): Awaitable<Message\IResponse> {
    $fun = $this->callback;
    return $fun($request);
  }
}
