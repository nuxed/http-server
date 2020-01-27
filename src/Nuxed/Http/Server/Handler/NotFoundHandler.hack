namespace Nuxed\Http\Server\Handler;

use namespace Nuxed\Http\Server\Exception;
use namespace Nuxed\Contract\Http\{Message, Server};

final class NotFoundHandler implements Server\IHandler {
  public async function handle(
    Message\IServerRequest $_request,
  ): Awaitable<Message\IResponse> {
    throw new Exception\ServerException(404, dict[]);
  }
}
