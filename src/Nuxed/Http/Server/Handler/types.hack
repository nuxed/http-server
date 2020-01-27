namespace Nuxed\Http\Server\Handler;

use namespace Nuxed\Contract\Http\{Message, Server};

type CallableHandler = (function(
  Message\IServerRequest,
): Awaitable<Message\IResponse>);

type DoublePassHandler = (function(
  Message\IServerRequest,
  Message\IResponse,
): Awaitable<Message\IResponse>);

type LazyHandler = (function(): Server\IHandler);
