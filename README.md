<p align="center"><img src="https://avatars3.githubusercontent.com/u/45311177?s=200&v=4"></p>

<p align="center">
<a href="https://travis-ci.org/nuxed/http-server"><img src="https://travis-ci.org/nuxed/http-server.svg" alt="Build Status"></a>
<a href="https://packagist.org/packages/nuxed/http-server"><img src="https://poser.pugx.org/nuxed/http-server/d/total.svg" alt="Total Downloads"></a>
<a href="https://packagist.org/packages/nuxed/http-server"><img src="https://poser.pugx.org/nuxed/http-server/v/stable.svg" alt="Latest Stable Version"></a>
<a href="https://packagist.org/packages/nuxed/http-server"><img src="https://poser.pugx.org/nuxed/http-server/license.svg" alt="License"></a>
</p>

# Nuxed Http Server

The Nuxed Http Server component provides a simple to use Http Server.

### Installation

This package can be installed with [Composer](https://getcomposer.org).

```console
$ composer require nuxed/http-server
```

### Example

```hack
use namespace Nuxed\Http\Server;
use namespace Nuxed\Http\Server\Socket;
use namespace Nuxed\Http\Message;

<<__EntryPoint>>
async function main(): Awaitable<void> {
  $options = Server\Options::create();
  
  $socket = await Socket\Server::listen(
    Socket\SocketAddress::create('tcp://127.0.0.1:8000')
  );

  $handler = Server\ch(async($request) ==> {
    $response = Message\Response\text('Hello, World!');
    $response = $response->withCookie('foo', Message\cookie('bar'));

    return $response;
  });

  $server = new Server\Server($socket, $handler);  

  await $server->run();
}
```

---

### Security

For information on reporting security vulnerabilities in Nuxed, see [SECURITY.md](SECURITY.md).

---

### License

Nuxed is open-sourced software licensed under the MIT-licensed.
