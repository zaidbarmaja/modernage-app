import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// خدمة مراقبة الاتصال بالشبكة (المهمة #1).
/// تكشف غياب الاتصال لحظياً ليُحجب الدخول إلى التطبيق حتى يعود الإنترنت.
class ConnectivityService extends ChangeNotifier {
  final Connectivity _conn = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _online = true; // نفترض الاتصال حتى يتبيّن العكس (لا نحجب بلا داعٍ)
  bool _checked = false;

  bool get online => _online;
  bool get checked => _checked;

  ConnectivityService() {
    _init();
  }

  Future<void> _init() async {
    try {
      _applyResult(await _conn.checkConnectivity());
    } catch (_) {
      _online = true; // إن فشل الفحص نفسه لا نحجب المستخدم
    }
    _checked = true;
    notifyListeners();
    _sub = _conn.onConnectivityChanged.listen(_applyResult);
  }

  void _applyResult(List<ConnectivityResult> results) {
    // قائمة فارغة أو تحتوي none فقط ⇒ غير متصل (any على فارغة = false).
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online != _online) {
      _online = online;
      notifyListeners();
    }
  }

  /// إعادة فحص الاتصال يدوياً (زر "إعادة المحاولة")؛ تعيد حالة الاتصال الحالية.
  Future<bool> recheck() async {
    try {
      _applyResult(await _conn.checkConnectivity());
    } catch (_) {
      // نُبقي الحالة كما هي عند فشل الفحص.
    }
    return _online;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
