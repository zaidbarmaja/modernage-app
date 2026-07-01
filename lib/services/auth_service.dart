import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../core/constants.dart';
import '../firebase_options.dart';
import '../models/app_user.dart';
import 'firestore_service.dart';

/// خدمة المصادقة عبر Firebase Auth.
/// الدخول يتم بـ"اسم الدخول" + كلمة المرور (الموظف/الإدارة باسم مستخدم،
/// والزبون برقم هاتفه). يُحوّل اسم الدخول داخلياً إلى بريد ثابت لأن Firebase
/// لا يدعم "اسم مستخدم + كلمة مرور" مباشرةً.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _fs = FirestoreService();

  User? get currentUser => _auth.currentUser;
  Stream<User?> authState() => _auth.authStateChanges();

  /// يحوّل اسم الدخول (اسم الموظف أو رقم هاتف الزبون) إلى بريد داخلي ثابت لا
  /// يظهر للمستخدم. يستخدم بصمة رقمية ثابتة عبر المنصّات لتعمل مع أي اسم
  /// (يشمل الأسماء العربية) ويبقى البريد صالحاً.
  /// تطبيع مُعرّف الدخول (اسم/هاتف) لمطابقة ثابتة.
  String _normId(String id) =>
      id.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String _idToEmail(String id) {
    final norm = _normId(id);
    var h = 0;
    for (final c in norm.codeUnits) {
      h = (h * 31 + c) % 1000000007;
    }
    return 'u$h@modernage.local';
  }

  /// بريد مصادقة فريد لنفس مُعرّف الدخول — يُستخدم حين يكون البريد الثابت محجوزاً
  /// من حساب قديم محذوف (لا يمكن حذف حساب Auth قديم من جهة العميل). الدخول يتم
  /// عبر اعتماد Firestore لا عبر هذا البريد، فلا يتأثّر تسجيل الدخول.
  String _uniqueEmail(String id) {
    final base = _idToEmail(id).split('@').first;
    final r = Random.secure();
    final suffix = List.generate(
        8, (_) => r.nextInt(36).toRadixString(36)).join();
    return '$base-$suffix@modernage.local';
  }

  /// تجزئة كلمة المرور المخزّنة في مجموعة credentials المنفصلة: ملح عشوائي لكل
  /// مستخدم + تمطيط (key stretching) لإبطاء أي هجوم تخمين. لا تُخزَّن كنصّ صريح
  /// ولا داخل ملف المستخدم.
  static const _pwSalt = 'modernage::pw::v1';
  static const _pwIterations = 12000;

  static String _stretch(String salt, String uid, String plain) {
    var digest = sha256.convert(utf8.encode('$_pwSalt|$salt|$uid|$plain'));
    for (var i = 1; i < _pwIterations; i++) {
      digest = sha256.convert(digest.bytes);
    }
    return digest.toString();
  }

  /// ملح عشوائي آمن (hex، 16 بايت) لكل عملية تعيين كلمة مرور.
  static String newSalt() {
    final r = Random.secure();
    return List.generate(
        16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// ينشئ بيانات اعتماد {salt, hash} لكلمة مرور (تُخزَّن في مجموعة credentials).
  static Map<String, String> makeCredential(String uid, String plain) {
    final salt = newSalt();
    return {'salt': salt, 'hash': _stretch(salt, uid, plain)};
  }

  /// يتحقّق من كلمة مرور ضدّ بيانات اعتماد مخزّنة.
  static bool verifyCredential(
          String uid, String plain, String salt, String hash) =>
      _stretch(salt, uid, plain) == hash;

  /// مفاتيح الدخول المطبّعة لحساب (الاسم + الهاتف إن وُجد) — للدخول بأيّهما.
  List<String> loginKeys(String loginId, String phone) {
    final keys = <String>{_normId(loginId)};
    if (phone.trim().isNotEmpty) keys.add(_normId(phone));
    return keys.toList();
  }

  /// "تذكّرني": على الويب يتحكّم ببقاء الجلسة بعد إغلاق المتصفّح
  /// (LOCAL = تبقى، SESSION = تنتهي بالإغلاق). على الموبايل تبقى الجلسة دائماً.
  Future<void> setRememberMe(bool remember) async {
    if (!kIsWeb) return;
    try {
      await _auth.setPersistence(
          remember ? Persistence.LOCAL : Persistence.SESSION);
    } catch (_) {
      // لا نُفشل الدخول إن تعذّر ضبط الإبقاء.
    }
  }

  /// جلسة Firebase داخلية ثابتة (Email/Password) لدخول المدير المُتحكَّم به من
  /// الكود (AppLogin): تُسجّل الدخول بالحساب الداخلي، وتُنشئه أول مرة إن لم يكن
  /// موجوداً (يطابق سلوك تطبيق الويب). يتطلّب تفعيل Email/Password في Firebase.
  Future<void> signInOrCreateInternal(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      final needsSignup = e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'invalid-login-credentials';
      if (!needsSignup) throw AuthException(_messageFor(e.code));
      try {
        await _auth.createUserWithEmailAndPassword(
            email: email, password: password);
      } on FirebaseAuthException catch (e2) {
        // الحساب موجود بكلمة مرور مختلفة → أعد خطأ الدخول الأصلي للوضوح.
        throw AuthException(_messageFor(
            e2.code == 'email-already-in-use' ? e.code : e2.code));
      }
    }
  }

  Future<void> signIn(String identifier, String password) async {
    // يدعم الدخول بالاسم أو الهاتف: نبحث عن بريد المصادقة بمفتاح الدخول،
    // وإلا نعتمد التحويل المباشر (يغطّي الاسم القانوني للحساب).
    String? email;
    try {
      email = await _fs.findAuthEmailByLogin(identifier);
    } catch (_) {
      email = null; // إن مُنع البحث (قواعد) نكمل بالتحويل المباشر.
    }
    try {
      await _auth.signInWithEmailAndPassword(
        email: email ?? _idToEmail(identifier),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  static const _secondaryAppName = 'employeeCreator';

  /// إعداد حساب المدير الأول (bootstrap): يُسمح به فقط حين لا يوجد أي مستخدم
  /// في النظام. بعد إنشاء المدير، يكون إنشاء الحسابات من لوحة الإدارة حصراً.
  Future<void> registerFirstAdmin({
    required String name,
    required String username,
    required String password,
  }) async {
    try {
      // كلمة Firebase داخلية قوية؛ الرمز الرباعي يُخزَّن كاعتماد Firestore.
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _idToEmail(username),
        password: newSalt(),
      );
      final isFirst = !(await _fs.hasAnyUser());
      if (!isFirst) {
        // يوجد مستخدمون بالفعل: لا يُسمح بالتسجيل الذاتي — نتراجع عن الحساب.
        await cred.user?.delete();
        throw const AuthException(
            'التسجيل الذاتي غير مسموح. تواصل مع الإدارة لإنشاء حسابك.');
      }
      await cred.user!.updateDisplayName(name);
      await _fs.createUser(AppUser(
        uid: cred.user!.uid,
        name: name.trim(),
        username: username.trim(),
        email: _idToEmail(username),
        loginNames: loginKeys(username, ''),
        role: UserRole.admin,
        department: Department.none,
        useFirestorePassword: true,
      ));
      final c = makeCredential(cred.user!.uid, password.trim());
      await _fs.setCredential(cred.user!.uid, c['salt']!, c['hash']!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  /// إنشاء حساب (موظف أو زبون) من لوحة الإدارة دون إخراج الأدمن من جلسته:
  /// تُنشأ بيانات المصادقة عبر نسخة Firebase ثانوية، ثم يُكتب ملف المستخدم
  /// عبر النسخة الأساسية (حيث الأدمن مصادَق) لتوافق قواعد الأمان.
  Future<String> _createAccount({
    required String name,
    required String loginId,
    required String code, // رمز الدخول (٤ أرقام) — يُخزَّن كاعتماد Firestore
    required UserRole role,
    required Department department,
    WorkCategory workCategory = WorkCategory.general,
    int? workStartMin, // اختياري: null = دوام غير محدّد (المهمة #4)
    int? workEndMin,
    String phone = '',
    String contact = '',
  }) async {
    FirebaseApp? secondary;
    try {
      for (final a in Firebase.apps) {
        if (a.name == _secondaryAppName) {
          secondary = a;
          break;
        }
      }
      secondary ??= await Firebase.initializeApp(
        name: _secondaryAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // كلمة Firebase داخلية قوية (لا يدخل بها المستخدم) — لتجاوز حدّ الـ٦ أحرف؛
      // الرمز الرباعي الظاهر يُخزَّن كاعتماد Firestore ويُفعَّل مساره.
      final secAuth = FirebaseAuth.instanceFor(app: secondary);
      var email = _idToEmail(loginId);
      UserCredential cred;
      try {
        cred = await secAuth.createUserWithEmailAndPassword(
            email: email, password: newSalt());
      } on FirebaseAuthException catch (e) {
        // البريد الثابت محجوز من حساب سابق محذوف (رقم/اسم أُعيد استخدامه) —
        // نولّد بريداً فريداً كي ينجح الإنشاء دائماً ويتحرّر الرقم للاستخدام.
        if (e.code != 'email-already-in-use') rethrow;
        email = _uniqueEmail(loginId);
        cred = await secAuth.createUserWithEmailAndPassword(
            email: email, password: newSalt());
      }
      final uid = cred.user!.uid;
      await cred.user!.updateDisplayName(name);
      await _fs.createUser(AppUser(
        uid: uid,
        name: name.trim(),
        username: loginId.trim(),
        email: email,
        loginNames: loginKeys(loginId, phone),
        phone: phone.trim(),
        role: role,
        department: department,
        workCategory: workCategory,
        workStartMin: workStartMin,
        workEndMin: workEndMin,
        contact: contact.trim(),
        useFirestorePassword: true,
      ));
      final c = makeCredential(uid, code.trim());
      await _fs.setCredential(uid, c['salt']!, c['hash']!);
      return uid;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    } finally {
      await secondary?.delete();
    }
  }

  /// إنشاء حساب موظف: اسم مستخدم + كلمة مرور + دور + قسم + وقت دوام مخصّص.
  Future<void> createEmployeeAccount({
    required String name,
    required String username,
    required String password,
    required UserRole role,
    required Department department,
    WorkCategory workCategory = WorkCategory.general,
    int? workStartMin,
    int? workEndMin,
    String phone = '',
  }) async {
    await _createAccount(
      name: name,
      loginId: username,
      code: password, // رمز الدخول (٤ أرقام)
      role: role,
      department: department,
      workCategory: workCategory,
      workStartMin: workStartMin,
      workEndMin: workEndMin,
      phone: phone,
    );
  }

  /// إنشاء حساب زبون: يدخل برقم هاتفه ورمز وصول من **٤ أرقام** (عبر مسار كلمة
  /// مرور Firestore — لتجاوز حدّ Firebase Auth البالغ ٦ أحرف).
  Future<void> createCustomerAccount({
    required String name,
    required String phone,
    required String accessCode,
    String contact = '',
  }) async {
    await _createAccount(
      name: name,
      loginId: phone,
      code: accessCode,
      role: UserRole.customer,
      department: Department.none,
      phone: phone,
      contact: contact,
    );
  }

  /// توليد رمز وصول رقمي (٤ خانات) لحساب الزبون.
  static String generateAccessCode() {
    final r = Random();
    return List.generate(4, (_) => r.nextInt(10)).join();
  }

  /// يغيّر المستخدم كلمة مروره بنفسه: يعيد المصادقة بكلمته الحالية ثم يحدّثها.
  /// متاح للحسابات الحقيقية فقط (لا يعمل في وضع الدخول التجريبي بلا Firebase).
  Future<void> changeOwnPassword(
      String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || (user.email ?? '').isEmpty) {
      throw const AuthException(
          'غير متاح: سجّل الدخول بحساب حقيقي لتغيير كلمة المرور.');
    }
    try {
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _messageFor(String code) {
    switch (code) {
      case 'invalid-email':
        return 'الاسم غير صالح.';
      case 'user-disabled':
        return 'هذا الحساب معطّل.';
      case 'user-not-found':
        return 'لا يوجد حساب بهذا الاسم.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'الاسم أو كلمة المرور غير صحيحة.';
      case 'email-already-in-use':
        return 'هذا الاسم مستخدم مسبقاً — اختر اسماً مختلفاً.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة (6 أحرف على الأقل).';
      case 'network-request-failed':
        return 'تعذّر الاتصال بالشبكة.';
      default:
        return 'حدث خطأ في المصادقة ($code).';
    }
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}
