import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../models/app_user.dart';
import 'auth_service.dart';
import 'firestore_service.dart';

/// حالة الجلسة:
/// - unknown: قيد التحديد/التحميل (شاشة البداية).
/// - unauthenticated: لا يوجد مستخدم مسجّل (شاشة الدخول).
/// - authenticated: مسجّل وملفه محمّل (التوجيه حسب الدور).
/// - noProfile: مسجّل في Firebase Auth لكن لا يوجد له ملف مستخدم في Firestore.
/// - error: فشل تحميل ملف المستخدم.
enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
  noProfile,
  error,
  disabled
}

/// يستمع لتغيّر تسجيل الدخول ويحمّل ملف المستخدم لحظياً، ويعالج كل الحالات
/// الحدّية حتى لا يعلق التطبيق على شاشة البداية إلى الأبد.
class AuthController extends ChangeNotifier {
  final AuthService _auth = AuthService();
  final FirestoreService _fs = FirestoreService();

  AuthStatus status = AuthStatus.unknown;
  AppUser? appUser;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<AppUser?>? _userSub;
  Timer? _profileTimer;

  /// وضع تطوير مؤقّت: جلسة محلية بدور محدّد بدون Firebase Auth.
  bool _localSession = false;

  AuthController() {
    _authSub = _auth.authState().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    // أثناء الجلسة المحلية (تطوير): تجاهل أحداث Firebase الفارغة.
    if (_localSession && user == null) return;
    _localSession = false;

    await _userSub?.cancel();
    _userSub = null;
    _profileTimer?.cancel();

    if (user == null) {
      appUser = null;
      _setStatus(AuthStatus.unauthenticated);
      return;
    }

    // مستخدم مسجّل: نعرض شاشة البداية ريثما يُحمّل ملفه.
    appUser = null;
    _setStatus(AuthStatus.unknown);

    _userSub = _fs.userStream(user.uid).listen(
      (profile) {
        _profileTimer?.cancel();
        if (profile != null) {
          appUser = profile;
          _setStatus(profile.active
              ? AuthStatus.authenticated
              : AuthStatus.disabled);
          return;
        }
        // لا يوجد ملف بعد: قد يكون قيد الإنشاء (تسجيل جديد) — ننتظر مهلة
        // قبل اعتبار الحساب بلا ملف، حتى لا نعرض تنبيهاً لحساب يُنشأ الآن.
        appUser = null;
        if (status != AuthStatus.unknown) _setStatus(AuthStatus.unknown);
        _profileTimer = Timer(const Duration(seconds: 8), () {
          if (appUser == null) _setStatus(AuthStatus.noProfile);
        });
      },
      onError: (Object _) {
        _profileTimer?.cancel();
        appUser = null;
        _setStatus(AuthStatus.error);
      },
    );
  }

  void _setStatus(AuthStatus s) {
    status = s;
    notifyListeners();
  }

  /// إعادة محاولة تحميل ملف المستخدم (تُستخدم في حالة الخطأ).
  void retry() {
    final user = _auth.currentUser;
    if (user != null) _onAuthChanged(user);
  }

  /// مدخل تطوير مؤقّت: دخول محلي بدور محدّد بدون Firebase Auth،
  /// لتصفّح شاشات الأدوار قبل تجهيز مشروع Firebase حقيقي. يُزال قبل الإطلاق.
  void loginLocalRole(UserRole role) {
    _localSession = true;
    _userSub?.cancel();
    _userSub = null;
    _profileTimer?.cancel();
    appUser = AppUser(
      uid: 'local-${role.id}',
      name: 'تجربة ${role.labelAr}',
      email: role.id,
      phone: role.id,
      role: role,
    );
    _setStatus(AuthStatus.authenticated);
  }

  Future<void> signOut() async {
    if (_localSession) {
      _localSession = false;
      appUser = null;
      _setStatus(AuthStatus.unauthenticated);
      return;
    }
    await _auth.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    _profileTimer?.cancel();
    super.dispose();
  }
}
