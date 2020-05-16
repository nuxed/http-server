namespace Nuxed\Http\Server\Examples\HelloWorld;

use namespace HH\Lib\TCP;
use namespace HH\Lib\Network;
use namespace Nuxed\Http\Server;
use namespace Nuxed\Http\Message;

require_once __DIR__.'/../vendor/autoload.hack';

<<__EntryPoint>>
async function main(): Awaitable<void> {
  \Facebook\AutoloadMap\initialize();

  $handler = Server\ch(async ($request) ==> {
    return Message\Response\text('Hello, World!');
  });

  $options = Server\Options::create();
  $server = new Server\Server($options, $handler);

  $socket = await Server\Socket\TCPServer::listen(
    Server\Socket\SocketAddress::create('tcp://localhost:1337'),
  );

  $server->listen($socket);

  await $server->run();
}
