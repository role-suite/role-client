/// Typed error from role-node's `{success:false, error:{code, message,
/// details, requestId}}` envelope. UI/retry logic branches on [code], never
/// on [message] text, per role-node/docs/guides/client-integration.md.
class RemoteApiException implements Exception {
  const RemoteApiException({required this.code, required this.message, this.requestId, this.details, this.retryAfterSeconds});

  final String code;
  final String message;
  final String? requestId;
  final Map<String, dynamic>? details;

  /// Parsed from the `Retry-After` response header on a `429
  /// RATE_LIMIT_EXCEEDED`, null otherwise. See §6/§11 of
  /// docs/08-ONLINE-MODE-INTEGRATION.md — the sync poller must pause for
  /// this long, not just fail the tick silently.
  final int? retryAfterSeconds;

  factory RemoteApiException.fromEnvelope(Map<String, dynamic> error, {int? retryAfterSeconds}) {
    return RemoteApiException(
      code: error['code'] as String? ?? 'UNKNOWN_ERROR',
      message: error['message'] as String? ?? 'Something went wrong.',
      requestId: error['requestId'] as String?,
      details: (error['details'] as Map?)?.cast<String, dynamic>(),
      retryAfterSeconds: retryAfterSeconds,
    );
  }

  /// No response at all (offline, DNS failure, timeout) — distinct from a
  /// 4xx/5xx the server actually answered with.
  factory RemoteApiException.network([String? message]) =>
      RemoteApiException(code: 'NETWORK_ERROR', message: message ?? 'Could not reach the server.');

  factory RemoteApiException.malformedResponse() =>
      const RemoteApiException(code: 'MALFORMED_RESPONSE', message: 'Server returned an unexpected response shape.');

  factory RemoteApiException.unknown(String message) => RemoteApiException(code: 'UNKNOWN_ERROR', message: message);

  @override
  String toString() => 'RemoteApiException($code: $message)';
}
