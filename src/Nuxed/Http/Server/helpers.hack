namespace Nuxed\Http\Server;

use namespace Nuxed\Contract\Http\{Message, Server};
use namespace Nuxed\Http\Message\Response;

/**
 * Callable Middleware Decorator.
 *
 * @see Middleware\CallableMiddlewareDecorator
 */
function cm(Middleware\CallableMiddleware $middleware): Server\IMiddleware {
  return new Middleware\CallableMiddlewareDecorator($middleware);
}

/**
 * Functional Middleware Decorator.
 */
function fm(Middleware\FunctionalMiddleware $middleware): Server\IMiddleware {
  return cm(
    ($request, $handler) ==>
      $middleware($request, ($request) ==> $handler->handle($request)),
  );
}

/**
 * Double Pass Middleware Decorator.
 */
function dm(Middleware\DoublePassMiddleware $middleware): Server\IMiddleware {
  return cm(($request, $handler) ==> {
    return $middleware($request, Response\empty(), $handler);
  });
}

/**
 * Double Pass Functional Middleware Decorator.
 */
function dfm(Middleware\DoublePassFunctionalMiddleware $middleware): Server\IMiddleware {
  return cm(($request, $handler) ==> {
    $next = ($request) ==> $handler->handle($request);
    return $middleware($request, Response\empty(), $next);
  });
}

/**
 * Lazy Middleware Decorator.
 */
function lm(Middleware\LazyMiddleware $factory): Server\IMiddleware {
  return cm(($request, $handler) ==> {
    return $factory()
      |> $$->process($request, $handler);
  });
}

/**
 * Callable Handler Decorator.
 *
 * @see Handler\CallableHandlerDecorator
 * @see cm
 */
function ch(Handler\CallableHandler $handler): Server\IHandler {
  return new Handler\CallableHandlerDecorator($handler);
}

/**
 * Double Pass Handler Decorator.
 *
 * @see dm
 */
function dh(Handler\DoublePassHandler $handler): Server\IHandler {
  return ch(($request) ==> {
    return $handler($request, Response\empty());
  });
}

/**
 * Lazy Handler Decorator.
 */
function lh(Handler\LazyHandler $factory): Server\IHandler {
  return ch((Message\IServerRequest $request) ==> {
    return $factory()
      |> $$->handle($request);
  });
}

/**
 * Handler Middleware Decorator.
 *
 * Decorate a request handler as middleware.
 *
 * When pulling handlers from a container, or creating pipelines, it's
 * simplest if everything is of the same type, so we do not need to worry
 * about varying execution based on type.
 *
 * To manage this, this function decorates request handlers as middleware, so that
 * they may be piped or routed to. When processed, they delegate handling to the
 * decorated handler, which will return a response.
 *
 * @see Middleware\HandlerMiddlewareDecorator
 */
function hm(Server\IHandler $handler): Middleware\HandlerMiddlewareDecorator {
  return new Middleware\HandlerMiddlewareDecorator($handler);
}

function host(
  string $host,
  Server\IMiddleware $middleware,
): Server\IMiddleware {
  return new Middleware\HostMiddlewareDecorator($host, $middleware);
}

function path(
  string $path,
  Server\IMiddleware $middleware,
): Server\IMiddleware {
  return new Middleware\PathMiddlewareDecorator($path, $middleware);
}

function stack(Server\IMiddleware ...$middleware): Server\IMiddlewareStack {
  $stack = new MiddlewareStack();
  foreach ($middleware as $mw) {
    $stack->stack($mw);
  }

  return $stack;
}
