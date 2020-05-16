namespace Nuxed\Http\Server\_Private;

/**
 * Format timestamp in seconds as an HTTP date header.
 *
 * @param int|null $timestamp Timestamp to format, current time if `null`.
 *
 * @return string Formatted date header value.
 */
function format_date_header(?int $timestamp = null): string {
  $timestamp = $timestamp ?? \time();
  return \gmdate('D, d M Y H:i:s', $timestamp).' GMT';
}
