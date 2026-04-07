String humanizeApiError(Object error) {
  var message = error.toString();
  if (message.startsWith('Exception: ')) {
    message = message.substring('Exception: '.length).trim();
  }
  final httpMatch = RegExp(r'^HTTP\s+\d{3}:\s*').firstMatch(message);
  if (httpMatch != null) {
    message = message.substring(httpMatch.end).trim();
  }
  return message.isEmpty ? 'Request failed.' : message;
}
