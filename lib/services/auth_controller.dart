import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_login.dart';
import '../core/constants.dart';
import '../models/app_user.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'notifications.dart';

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

  /// مفتاح حفظ جلسة التطوير عند تفعيل "تذكّرني" (تبقى بعد تحديث الصفحة).
  static const _devRoleKey = 'devSessionRole';
  /// مفتاح حفظ جلسة حساب حقيقي يدخل عبر كلمة مرور Firestore (جلسة محلية).
  static const _localUidKey = 'localSessionUid';
  bool _checkingDev = true; // ريثما نفحص جلسة تطوير محفوظة قبل إظهار الدخول

  /// انتحال جلسة: الأدمن يدخل حساب مستخدم آخر ويتصرّف كأنه هو.
  AppUser? _realUser; // ملف الأدمن المحفوظ أثناء الانتحال
  AppUser? impersonatedUser; // الحساب الجاري تصفّحه (null = لا انتحال)
  bool get isImpersonating => impersonatedUser != null;

  AuthController() {
    _restoreDevSession();
    _authSub = _auth.authState().listen(_onAuthChanged);
  }

  /// يستعيد جلسة التطوير المحفوظة (إن فُعّل "تذكّرني") قبل إظهار شاشة الدخول.
  Future<void> _restoreDevSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roleId = prefs.getString(_devRoleKey);
      if (roleId != null && _auth.currentUser == null) {
        _checkingDev = false;
        loginLocalRole(UserRoleX.fromId(roleId), remember: true);
        return;
      }
      // جلسة حساب حقيقي عبر كلمة مرور Firestore: نعيد تحميل ملفه ونستأنفها.
      final localUid = prefs.getString(_localUidKey);
      if (localUid != null && _auth.currentUser == null) {
        _checkingDev = false;
        final u = await _fs.getUser(localUid);
        if (u != null && u.active) {
          loginAsUser(u, remember: true);
          return;
        }
        await prefs.remove(_localUidKey); // الملف غاب/عُطّل: امسح الجلسة.
      }
    } catch (_) {
      // نتجاهل أي فشل في القراءة ونكمل لشاشة الدخول.
    }
    _checkingDev = false;
    if (!_localSession && _auth.currentUser == null) {
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  Future<void> _onAuthChanged(User? user) async {
    // أثناء الجلسة المحلية (تطوير): تجاهل أحداث Firebase الفارغة.
    if (_localSession && user == null) return;
    // ريثما نفحص جلسة التطوير المحفوظة: لا نُظهر شاشة الدخول بعد.
    if (_checkingDev && user == null) return;
    _localSession = false;

    await _userSub?.cancel();
    _userSub = null;
    _profileTimer?.cancel();

    if (user == null) {
      appUser = null;
      _setStatus(AuthStatus.unauthenticated);
      return;
    }

    // مدير الكود (AppLogin): الدخول بحساب المصادقة الداخلي الثابت → ملف مدير
    // اصطناعي بصلاحية كاملة دون الحاجة لملف Firestore (يطابق نموذج تطبيق الويب).
    // يعمل أيضاً عند استعادة الجلسة تلقائياً بعد إعادة فتح التطبيق.
    if (user.email == AppLogin.authEmail) {
      appUser = AppUser(
        uid: user.uid,
        name: AppLogin.displayName,
        username: AppLogin.username,
        email: AppLogin.authEmail,
        role: UserRole.admin,
      );
      _setStatus(AuthStatus.authenticated);
      return;
    }

    // مستخدم مسجّل: نعرض شاشة البداية ريثما يُحمّل ملفه.
    appUser = null;
    _setStatus(AuthStatus.unknown);

    _userSub = _fs.userStream(user.uid).listen(
      (profile) {
        _profileTimer?.cancel();
        // أثناء الانتحال: حدّث ملف الأدمن المحفوظ فقط دون تغيير الجلسة الظاهرة.
        if (isImpersonating) {
          if (profile != null) _realUser = profile;
          return;
        }
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
        if (isImpersonating) return; // لا نُربك جلسة الانتحال بخطأ ملف الأدمن
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
  void loginLocalRole(UserRole role, {bool remember = false}) {
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
    // "تذكّرني": احفظ الدور لتبقى الجلسة بعد التحديث، وإلا امسح أي جلسة محفوظة.
    SharedPreferences.getInstance().then((p) {
      if (remember) {
        p.setString(_devRoleKey, role.id);
      } else {
        p.remove(_devRoleKey);
      }
    }).ignore();
    _setStatus(AuthStatus.authenticated);
  }

  /// دخول موحّد: يحدّد المسار حسب ملف المستخدم. الحسابات التي أعاد المدير ضبط
  /// كلمة مرورها (useFirestorePassword) يُتحقّق منها عبر تجزئة Firestore وتُفتح
  /// كجلسة محلية؛ وبقية الحسابات تمرّ بمسار Firebase Auth كالمعتاد.
  Future<void> login(String identifier, String password,
      {bool remember = false}) async {
    final user = await _fs.findUserByLogin(identifier);
    if (user != null && user.useFirestorePassword) {
      if (!user.active) {
        throw const AuthException('هذا الحساب معطّل. تواصل مع الإدارة.');
      }
      final cred = await _fs.getCredential(user.uid);
      // نقصّ كما يُقصّ عند الضبط كي يتطابق الجانبان.
      final ok = cred != null &&
          AuthService.verifyCredential(
              user.uid, password.trim(), cred['salt']!, cred['hash']!);
      if (!ok) {
        throw const AuthException('الاسم أو كلمة المرور غير صحيحة.');
      }
      loginAsUser(user, remember: remember);
      return;
    }
    await _auth.setRememberMe(remember);
    await _auth.signIn(identifier, password);
  }

  /// دخول المدير (AppLogin): يفتح جلسة Firebase حقيقية بالحساب الداخلي الثابت
  /// (لصلاحية قاعدة البيانات) باستخدام كلمة المرور التي أدخلها المدير يدويًا —
  /// لا تُخزَّن في الكود. ثم يُضبط ملف المدير الاصطناعي تلقائياً عبر مستمع
  /// حالة المصادقة (_onAuthChanged).
  Future<void> loginCodeAdmin(String password, {bool remember = false}) async {
    await _auth.setRememberMe(remember);
    await _auth.signInOrCreateInternal(AppLogin.authEmail, password);
  }

  /// يفتح جلسة بحساب حقيقي (uid/دور حقيقيان) دون Firebase Auth — تُستخدم بعد
  /// التحقّق من كلمة مرور Firestore. تُحفظ إن فُعّل "تذكّرني" لتبقى بعد التحديث.
  /// يربط مستمعاً حيّاً لملف المستخدم كي يسري التعطيل/الحذف فوراً أثناء الجلسة.
  void loginAsUser(AppUser u, {bool remember = false}) {
    _localSession = true;
    _userSub?.cancel();
    _profileTimer?.cancel();
    appUser = u;
    _userSub = _fs.userStream(u.uid).listen(
      (profile) {
        if (isImpersonating) return;
        if (profile == null) {
          _endLocalSession(); // حُذف الحساب: إنهاء الجلسة.
          return;
        }
        if (!profile.active) {
          appUser = profile;
          _clearSavedLocalUid();
          _setStatus(AuthStatus.disabled); // عُطّل: يُطرد فوراً.
          return;
        }
        appUser = profile;
        _setStatus(AuthStatus.authenticated);
      },
      onError: (Object _) {
        // قواعد مشدّدة قد تمنع القراءة بلا Firebase Auth — نُبقي الجلسة كما هي.
      },
    );
    SharedPreferences.getInstance().then((p) {
      if (remember) {
        p.setString(_localUidKey, u.uid);
        p.remove(_devRoleKey);
      } else {
        p.remove(_localUidKey);
      }
    }).ignore();
    _setStatus(AuthStatus.authenticated);
  }

  void _clearSavedLocalUid() {
    SharedPreferences.getInstance()
        .then((p) => p.remove(_localUidKey))
        .ignore();
  }

  void _endLocalSession() {
    _userSub?.cancel();
    _userSub = null;
    _localSession = false;
    appUser = null;
    _clearSavedLocalUid();
    _setStatus(AuthStatus.unauthenticated);
  }

  /// يدخل الأدمن إلى حساب [target] ويتصرّف كأنه هو (الإجراءات تُنسب إليه).
  /// يبقى الأدمن مصادَقاً فعلياً، وتُبدَّل فقط الجلسة الظاهرة في التطبيق.
  void impersonate(AppUser target) {
    if (appUser?.uid == target.uid) return;
    _realUser ??= appUser; // احفظ ملف الأدمن أول مرة فقط
    impersonatedUser = target;
    appUser = target;
    _setStatus(AuthStatus.authenticated);
  }

  /// يعود الأدمن إلى حسابه بعد الانتحال.
  void stopImpersonating() {
    if (!isImpersonating) return;
    if (_realUser != null) appUser = _realUser;
    _realUser = null;
    impersonatedUser = null;
    _setStatus(AuthStatus.authenticated);
  }

  Future<void> signOut() async {
    _realUser = null;
    impersonatedUser = null;
    // ألغِ تذكيرات المستخدم المحلية كي لا تبقى تظهر على الجهاز بعد خروجه.
    await Notifications.cancelAll();
    // امسح الجلسات المحلية المحفوظة (تطوير/كلمة مرور Firestore) كي لا تُستعاد.
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_devRoleKey);
      await p.remove(_localUidKey);
    } catch (_) {}
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
