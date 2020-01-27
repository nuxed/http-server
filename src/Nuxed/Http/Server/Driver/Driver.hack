namespace Nuxed\Http\Server\Driver;

use namespace HH\Lib\Str;
use namespace Nuxed\Http\Server\{Exception, Parser, Responder, Socket, Handler};
use namespace Nuxed\Contract\Http\Message;
use namespace Nuxed\Contract\Log;
use namespace Nuxed\Contract\Http\Server;
use namespace Nuxed\Http;

final class Driver implements IDriver {
  private Parser\IParser $parser;
  private Responder\IResponder $responder;

  public function __construct(
    private Http\Server\Options $options,
    ?Parser\IParser $parser = null,
    ?Responder\IResponder $responder = null,
  ) {
    $this->parser = $parser ?? new Parser\Parser($options);
    $this->responder = $responder ?? new Responder\Responder($options);
  }

  public async function handle(
    Socket\IConnection $connection,
    Server\IMiddlewareStack $stack,
    Server\IHandler $handler,
  ): Awaitable<void> {
    $request = null;
    try {
      $request = await $this->parse($connection);
      $handler = new Handler\StackHandler($stack, $handler);
      $response = await $handler->handle($request);
    } catch (Exception\ServerException $e) {
      $response = Http\Message\Response\empty()
        ->withStatus($e->getStatusCode());
      foreach ($e->getHeaders() as $header => $values) {
        $response = $response->withHeader($header, $values);
      }

      $body = $e->getBody();
      if ($body is nonnull) {
        $response = $response->withBody($body);
      }
    }

    await $this->respond($connection, $response, $request);
  }

  public async function parse(
    Socket\IConnection $connection,
  ): Awaitable<Message\IServerRequest> {
    return await $this->parser->parse($connection);
  }

  public async function respond(
    Socket\IConnection $connection,
    Message\IResponse $response,
    ?Message\IServerRequest $request = null,
  ): Awaitable<void> {
    await $this->responder->respond($connection, $response, $request);
  }
}
