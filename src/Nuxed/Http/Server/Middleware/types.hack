namespace Nuxed\Http\Server\Middleware;

use namespace Nuxed\Contract\Http\{Message, Server};
use namespace Nuxed\Http\Server\Handler;

type CallableMiddleware = (function(
  Message\IServerRequest,
  Server\IHandler,
): Awaitable<Message\IResponse>);

type FunctionalMiddleware = (function(
  Message\IServerRequest,
  Handler\CallableHandler,
): Awaitable<Message\IResponse>);

type DoublePassMiddleware = (function(
  Message\IServerRequest,
  Message\IResponse,
  Server\IHandler,
): Awaitable<Message\IResponse>);

type DoublePassFunctionalMiddleware = (function(
  Message\IServerRequest,
  Message\IResponse,
  Handler\CallableHandler,
): Awaitable<Message\IResponse>);

type LazyMiddleware = (function(): Server\IMiddleware);
