import 'dart:math';

class CodeGenerator {
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No O, 0, 1, I to avoid confusion

  /// Generates a human-friendly 6-character invite code: e.g. "TRIP-7K9X"
  static String generateInviteCode({String prefix = 'TRIP'}) {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (int i = 0; i < 4; i++) {
      buffer.write(_chars[random.nextInt(_chars.length)]);
    }
    return '$prefix-${buffer.toString()}';
  }
}
