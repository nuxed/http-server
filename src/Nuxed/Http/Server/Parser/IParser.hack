namespace Nuxed\Http\Server\Parser;

use namespace Nuxed\Http\Server\Socket;
use namespace Nuxed\Contract\Http\Message;

interface IParser {
  public function parse(
    Socket\IConnection $connection,
  ): Awaitable<Message\IServerRequest>;
}
