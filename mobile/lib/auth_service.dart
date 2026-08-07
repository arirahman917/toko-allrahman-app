import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserName = 'user_name';
  static const String _keyUserRole = 'user_role';
  static const String _keyUuidPrefix = 'uuid_prefix';
  static const String _keyUserPhone = 'user_phone';

  /// Login dengan no HP dan password via Supabase (ONLINE).
  /// Mengembalikan nama user jika berhasil, null jika gagal.
  /// Throws exception jika tidak ada koneksi internet.
  static Future<String?> login(String phone, String password) async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('users')
          .select()
          .eq('phone', phone)
          .eq('password', password)
          .maybeSingle();

      if (response != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyIsLoggedIn, true);
        await prefs.setString(_keyUserName, response['name']);
        await prefs.setString(_keyUserRole, response['role']);
        await prefs.setString(_keyUuidPrefix, response['uuid_prefix']);
        await prefs.setString(_keyUserPhone, response['phone']);
        return response['name'];
      }
      return null; // Kredensial salah
    } catch (e) {
      // Bisa terjadi jika tidak ada internet / tabel belum ada
      rethrow;
    }
  }

  /// Cek apakah user sudah login (session persistent, OFFLINE OK)
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  /// Ambil nama user yang sedang login
  static Future<String> getCurrentUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName) ?? 'Guest';
  }

  /// Ambil role user yang sedang login
  static Future<String> getCurrentUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserRole) ?? 'guest';
  }

  /// Ambil UUID prefix user yang sedang login
  static Future<String> getCurrentUuidPrefix() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUuidPrefix) ?? 'Guest';
  }

  /// Ambil phone user yang sedang login
  static Future<String> getCurrentUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserPhone) ?? '';
  }

  /// Logout dan hapus session
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyUuidPrefix);
    await prefs.remove(_keyUserPhone);
  }
}
