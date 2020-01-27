namespace Nuxed\Http\Server\Middleware;

use namespace Nuxed\Contract\Http\{Message, Server};

final class OriginalMessagesMiddleware implements Server\IMiddleware {
  public async function process(
    Message\IServerRequest $request,
    Server\IHandler $handler,
  ): Awaitable<Message\IResponse> {
    return await $handler->handle(
      $request
        ->withAttribute('OriginalUri', $request->getUri())
        ->withAttribute('OriginalRequest', $request),
    );
  }
}
