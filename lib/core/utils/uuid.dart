import 'dart:math';

class UuidUtils {
  static final Random _random = Random();

  static String generate() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomPart = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '$timestamp-$randomPart';
  }
}
