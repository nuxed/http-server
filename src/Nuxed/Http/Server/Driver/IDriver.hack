namespace Nuxed\Http\Server\Driver;

use namespace Nuxed\Http\Server\{Parser, Responder, Socket};
use namespace Nuxed\Contract\Http\Server;

interface IDriver extends Responder\IResponder, Parser\IParser {
  public function handle(
    Socket\IConnection $connection,
    Server\IMiddlewareStack $stack,
    Server\IHandler $handler,
  ): Awaitable<void>;
}
