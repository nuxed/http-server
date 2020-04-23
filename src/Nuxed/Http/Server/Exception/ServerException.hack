namespace Nuxed\Http\Server\Exception;

use namespace Nuxed\Contract\Http\Message;
use namespace HH\Lib\IO;

use type Nuxed\Http\Message\Response;

final class ServerException extends RuntimeException {
  public function __construct(
    protected int $status = Message\StatusCode::InternalServerError,
    protected KeyedContainer<string, Container<string>> $headers = dict[],
    protected ?IO\SeekableReadWriteHandle $body = null,
  ) {
    parent::__construct(Response::$phrases[$status] ?? Response::$phrases[500]);
  }

  public function getStatusCode(): int {
    return $this->status;
  }

  public function getHeaders(): KeyedContainer<string, Container<string>> {
    return $this->headers;
  }

  public function getBody(): ?IO\SeekableReadWriteHandle {
    return $this->body;
  }
}
