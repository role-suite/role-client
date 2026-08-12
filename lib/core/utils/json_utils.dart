Map<String, String> stringMapFrom(dynamic value) {
  if (value is Map) {
    return value.map((key, v) => MapEntry(key.toString(), v?.toString() ?? ''));
  }
  return const {};
}

DateTime dateTimeFrom(dynamic value, {DateTime? fallback}) {
  if (value is String) {
    return DateTime.tryParse(value) ?? fallback ?? DateTime.now();
  }
  return fallback ?? DateTime.now();
}
