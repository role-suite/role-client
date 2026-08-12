import 'dart:math';

final _random = Random.secure();

/// Generates a short, locally-unique id (timestamp + random suffix).
/// Not a spec-compliant UUID — Röle is local-only and never needs
/// globally-unique ids, just stable, collision-free local ones.
String generateId([String prefix = '']) {
  final millis = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final suffix = List.generate(8, (_) => _random.nextInt(36).toRadixString(36)).join();
  return prefix.isEmpty ? '$millis$suffix' : '$prefix-$millis$suffix';
}
