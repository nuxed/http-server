namespace Nuxed\Http\Server\Responder;

use namespace Nuxed\Contract\Http\Message;
use namespace Nuxed\Http\Server\Socket;

interface IResponder {
  /**
   * Respond to the client connection with the given response.
   */
  public function respond(
    Socket\IConnection $connection,
    Message\IResponse $response,
    ?Message\IServerRequest $request = null,
  ): Awaitable<void>;
}
