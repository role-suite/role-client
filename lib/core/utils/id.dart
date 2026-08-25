import 'dart:math';

final _random = Random.secure();

/// Generates a UUIDv4, optionally prefixed (e.g. `col-<uuid>`).
///
/// UUIDv4 (rather than a timestamp+random scheme) so ids stay collision-safe
/// once they double as outbox entry keys and, per role-node's dual-id sync
/// design, the app's own stable local key regardless of any server-assigned
/// remote id.
String generateId([String prefix = '']) {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx

  String hex(int start, int end) => bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  final uuid = '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  return prefix.isEmpty ? uuid : '$prefix-$uuid';
}
