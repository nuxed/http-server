namespace Nuxed\Http\Server\Socket;

enum SocketAddressScheme: string as string {
  Unix = 'unix';
  TCP = 'tcp';
}
