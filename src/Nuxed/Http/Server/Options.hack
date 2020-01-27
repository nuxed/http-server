namespace Nuxed\Http\Server;

use namespace HH\Lib\{C, Vec};

final class Options {
  private bool $debug = false;
  private int $connectionLimit = 10000;
  private int $connectionsPerIpLimit =
    30; // IPv4: /32, IPv6: /56 (per RFC 6177)
  private float $httpTimeout = 15.0; // seconds

  private vec<string> $allowedMethods =
    vec["GET", "POST", "PUT", "PATCH", "HEAD", "OPTIONS", "DELETE"];

  private int $bodySizeLimit = 131072;
  private int $headerSizeLimit = 32768;
  private int $chunkSize = 8192;
  private int $streamThreshold = 8192;

  private bool $fileUpload = true;
  private int $uploadedFileSizeLimit = 2048;
  private int $uploadedFileLimit = 100;

  private bool $xPoweredBy = true;

  private function __construct(): void {}

  /**
   * Create an options object.
   */
  public static function create(): Options {
    return new Options();
  }

  /**
   * Enable Nuxed `X-Powered-By` default header.
   */
  public function withXPoweredBy(): Options {
    $new = clone $this;
    $new->xPoweredBy = true;

    return $new;
  }

  /**
   * Disable Nuxed `X-Powered-By` default header.
   *
   * Note: disabling the `X-Powered-By` header doesn't improve your applications
   * security.
   */
  public function withoutXPoweredBy(): Options {
    $new = clone $this;
    $new->xPoweredBy = false;

    return $new;
  }

  /**
   * @return bool `true` if the server is allowed to send `X-Powered-By` header, `false` otherwise.
   */
  public function hasXPoweredBy(): bool {
    return $this->xPoweredBy;
  }

  /**
   * @return bool `true` if server is in debug mode, `false` if in production mode.
   */
  public function isInDebugMode(): bool {
    return $this->debug;
  }

  /**
   * Sets debug mode to `true`.
   */
  public function withDebugMode(): Options {
    $new = clone $this;
    $new->debug = true;

    return $new;
  }

  /**
   * Sets debug mode to `false`.
   */
  public function withoutDebugMode(): Options {
    $new = clone $this;
    $new->debug = false;

    return $new;
  }

  /**
   * @return int The maximum number of connections that can be handled by the server at a single time.
   */
  public function getConnectionLimit(): int {
    return $this->connectionLimit;
  }

  /**
   * @param int $count Maximum number of connections the server should accept at one time. Default is 10000.
   */
  public function withConnectionLimit(int $count): Options {
    invariant(
      $count >= 1,
      'Connection limit setting must be greater than or equal to one',
    );

    $new = clone $this;
    $new->connectionLimit = $count;

    return $new;
  }

  /**
   * @return int The maximum number of connections allowed from a single IP.
   */
  public function getConnectionsPerIpLimit(): int {
    return $this->connectionsPerIpLimit;
  }

  /**
   * @param int $count Maximum number of connections to allow from a single IP address. Default is 30.
   */
  public function withConnectionsPerIpLimit(int $count): Options {
    invariant(
      $count >= 1,
      'Connections per IP maximum must be greater than or equal to one',
    );

    $new = clone $this;
    $new->connectionsPerIpLimit = $count;

    return $new;
  }

  /**
   * @return int Number of seconds an HTTP/1.x connection may be idle before it is automatically closed.
   */
  public function getHttpTimeout(): float {
    return $this->httpTimeout;
  }

  /**
   * @param int $seconds Number of seconds an HTTP/1.x connection may be idle before it is automatically closed.
   *                     Default is 15.
   */
  public function withHttpTimeout(float $seconds): Options {
    invariant(
      $seconds >= 1,
      'Keep alive timeout setting must be greater than or equal to one second',
    );

    $new = clone $this;
    $new->httpTimeout = $seconds;

    return $new;
  }

  /**
   * @return int Maximum request body size in bytes.
   */
  public function getBodySizeLimit(): int {
    return $this->bodySizeLimit;
  }

  /**
   * @param int $bytes Default maximum request body size in bytes. Default is 131072 (128k).
   */
  public function withBodySizeLimit(int $bytes): Options {
    invariant(
      $bytes >= 1,
      'Max body size setting must be greater than or equal to zero',
    );

    $new = clone $this;
    $new->bodySizeLimit = $bytes;

    return $new;
  }

  /**
   * @return int Maximum size of the request header section in bytes.
   */
  public function getHeaderSizeLimit(): int {
    return $this->headerSizeLimit;
  }

  /**
   * @param int $bytes Maximum size of the request header section in bytes. Default is 32768 (32k).
   */
  public function withHeaderSizeLimit(int $bytes): Options {
    invariant($bytes >= 1, 'Max header size setting must be greater than zero');

    $new = clone $this;
    $new->headerSizeLimit = $bytes;

    return $new;
  }

  /**
   * @return int The maximum number of bytes to read from a client per read.
   */
  public function getChunkSize(): int {
    return $this->chunkSize;
  }

  /**
   * @param int $bytes The maximum number of bytes to read from a client per read. Larger numbers are better for
   *                   performance but can increase memory usage. Default is 8192 (8k).
   */
  public function withChunkSize(int $bytes): Options {
    invariant($bytes >= 1, 'Chunk size setting must be greater than zero');

    $new = clone $this;
    $new->chunkSize = $bytes;

    return $new;
  }

  /**
   * @return int The minimum number of bytes to write to a client time for streamed responses.
   */
  public function getStreamThreshold(): int {
    return $this->streamThreshold;
  }

  /**
   * @param int $bytes The minimum number of bytes to write to a client time for streamed responses. Larger numbers
   *                   are better for performance but can increase memory usage. Default is 1024 (1k).
   */
  public function withStreamThreshold(int $bytes): Options {
    invariant(
      $bytes >= 1,
      'Stream threshold setting must be greater than zero',
    );

    $new = clone $this;
    $new->streamThreshold = $bytes;

    return $new;
  }

  /**
   * @return Container<string> A container of allowed request methods.
   */
  public function getAllowedMethods(): Container<string> {
    return $this->allowedMethods;
  }

  /**
   * @param Container<string> $allowedMethods A container of allowed request methods. Default is GET, POST, PUT, PATCH,
   *                                  HEAD, OPTIONS, DELETE.
   */
  public function withAllowedMethods(
    Container<string> $allowedMethods,
  ): Options {
    foreach ($allowedMethods as $method) {
      invariant('' !== $method, 'Invalid empty HTTP method.');
    }

    $allowedMethods = Vec\unique($allowedMethods);

    invariant(
      C\contains($allowedMethods, 'GET'),
      'Servers must support GET as an allowed HTTP method',
    );
    invariant(
      C\contains($allowedMethods, 'HEAD'),
      'Servers must support HEAD as an allowed HTTP method',
    );

    $new = clone $this;
    $new->allowedMethods = $allowedMethods;

    return $new;
  }

  /**
   * Enables file upload.
   */
  public function withFileUpload(): this {
    $new = clone $this;
    $new->fileUpload = true;

    return $new;
  }

  /**
   * Disables file upload.
   */
  public function withoutFileUpload(): this {
    $new = clone $this;
    $new->fileUpload = false;

    return $new;
  }

  /**
   * @return bool `true` if file upload feature is enabled. `false` it is disabled.
   */
  public function hasFileUplaod(): bool {
    return $this->fileUpload;
  }

  /**
   * @param int $bytes The maximum uploaded file size accepted by the server.
   */
  public function withUploadedFileSizeLimit(int $bytes): this {
    invariant(
      $this->hasFileUplaod(),
      'File upload is turned off. please enabled file upload via `$options->withFileUplaod()` first.',
    );
    invariant(
      $bytes >= 1,
      'Expected `$bytes` to be greater or equal to 1, %d given.',
      $bytes,
    );

    $new = clone $this;
    $new->uploadedFileSizeLimit = $bytes;

    return $new;
  }

  /**
   * @return int The maximum uploaded file size accepted by the server.
   */
  public function getUploadedFileSizeLimit(): int {
    return $this->uploadedFileSizeLimit;
  }

  /**
   * @param int $limit The uploaded files limit accepted by the server in one request.
   */
  public function withUploadedFilesLimit(int $limit): this {
    invariant(
      $this->hasFileUplaod(),
      'File upload is turned off. please enabled file upload via `$options->withFileUplaod()` first.',
    );

    invariant(
      $limit >= 1,
      'Expected `$limit` to be greater or equal to 1, %d given.',
      $limit,
    );

    $new = clone $this;
    $new->uploadedFileLimit = $limit;

    return $new;
  }

  /**
   * @return int The uploaded files limit accepted by the server in one request.
   */
  public function getUploadedFilesLimit(): int {
    return $this->uploadedFileLimit;
  }
}
