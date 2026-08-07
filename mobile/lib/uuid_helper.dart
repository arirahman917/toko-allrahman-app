import 'package:uuid/uuid.dart';

class UuidHelper {
  static const _uuid = Uuid();

  /// Generate UUID (sekarang murni standar UUID)
  /// Prefix user akan ditambahkan saat sync ke Supabase di kolom created_by
  static Future<String> generatePrefixed() async {
    return _uuid.v4();
  }

  /// Generate UUID tanpa prefix
  static String generate() {
    return _uuid.v4();
  }
}
