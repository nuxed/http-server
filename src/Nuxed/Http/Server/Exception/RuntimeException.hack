namespace Nuxed\Http\Server\Exception;

use namespace Nuxed\Contract\Http\Server\Exception;

<<__Sealed(ServerException::class)>>
class RuntimeException
  extends \RuntimeException
  implements Exception\IException {
}
