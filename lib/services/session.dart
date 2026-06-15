import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// جلسة الموظف لكل دور (تصميم/تنفيذ/بصمة) — تقابل sessionStorage في الويب.
/// تُحفظ في shared_preferences لتبقى بعد إعادة فتح التطبيق.
class EmployeeSession {
  final String id;
  final String name;
  const EmployeeSession(this.id, this.name);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  static EmployeeSession? fromJson(Map<String, dynamic>? j) {
    if (j == null || j['id'] == null) return null;
    return EmployeeSession(j['id'].toString(), (j['name'] ?? '').toString());
  }
}

class Session {
  static const designKey = 'designEmployee';
  static const executionKey = 'executionEmployee';
  static const fingerprintKey = 'fingerprintEmployee';

  static SharedPreferences? _prefs;
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static EmployeeSession? get(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null) return null;
    try {
      return EmployeeSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> set(String key, EmployeeSession s) async {
    await _prefs?.setString(key, jsonEncode(s.toJson()));
  }

  static Future<void> clear(String key) async {
    await _prefs?.remove(key);
  }

  // ===== العميل (بوابة العملاء) =====
  static const customerKey = 'clientCustomer';
  static const favoritesKey = 'clientFavorites';

  static Map<String, dynamic>? getCustomer() {
    final raw = _prefs?.getString(customerKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setCustomer(Map<String, dynamic>? c) async {
    if (c == null) {
      await _prefs?.remove(customerKey);
    } else {
      await _prefs?.setString(customerKey, jsonEncode(c));
    }
  }

  static List<String> getFavorites() {
    return _prefs?.getStringList(favoritesKey) ?? <String>[];
  }

  static Future<void> setFavorites(List<String> favs) async {
    await _prefs?.setStringList(favoritesKey, favs);
  }
}
