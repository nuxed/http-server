namespace Nuxed\Http\Server\Middleware;

use namespace HH\Lib\{C, Str};
use namespace Nuxed\Contract\Http\{Message, Server};
use namespace Nuxed\Http\Server\Parser;

final class RequestBodyParserMiddleware implements Server\IMiddleware {
  public function __construct(
    private Parser\MultipartParser $multipart,
    private Parser\UrlEncodedParser $urlEncoded,
  ) {}

  public async function process(
    Message\IServerRequest $request,
    Server\IHandler $handler,
  ): Awaitable<Message\IResponse> {
    if (!$request->hasHeader('content-type')) {
      return await $handler->handle($request);
    }

    $contentType = $request->getHeader('content-type');
    $contentType = Str\lowercase(C\firstx($contentType));
    if ('application/x-www-form-urlencoded' === $contentType) {
      $request = await $this->urlEncoded->parse($request);
    } else if ('multipart/form-data' === $contentType) {
      $request = await $this->multipart->parse($request);
    }

    return await $handler->handle($request);
  }
}
