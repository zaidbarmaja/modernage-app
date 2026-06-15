import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

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

  /// مفاتيح الدخول المطبّعة لحساب (الاسم + الهاتف إن وُجد) — للدخول بأيّهما.
  List<String> loginKeys(String loginId, String phone) {
    final keys = <String>{_normId(loginId)};
    if (phone.trim().isNotEmpty) keys.add(_normId(phone));
    return keys.toList();
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
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _idToEmail(username),
        password: password,
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
      ));
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  /// إنشاء حساب (موظف أو زبون) من لوحة الإدارة دون إخراج الأدمن من جلسته:
  /// تُنشأ بيانات المصادقة عبر نسخة Firebase ثانوية، ثم يُكتب ملف المستخدم
  /// عبر النسخة الأساسية (حيث الأدمن مصادَق) لتوافق قواعد الأمان.
  Future<void> _createAccount({
    required String name,
    required String loginId,
    required String password,
    required UserRole role,
    required Department department,
    int workStartMin = 8 * 60,
    int workEndMin = 16 * 60,
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
      final cred = await FirebaseAuth.instanceFor(app: secondary)
          .createUserWithEmailAndPassword(
        email: _idToEmail(loginId),
        password: password,
      );
      await cred.user!.updateDisplayName(name);
      await _fs.createUser(AppUser(
        uid: cred.user!.uid,
        name: name.trim(),
        username: loginId.trim(),
        email: _idToEmail(loginId),
        loginNames: loginKeys(loginId, phone),
        phone: phone.trim(),
        role: role,
        department: department,
        workStartMin: workStartMin,
        workEndMin: workEndMin,
        contact: contact.trim(),
      ));
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
    int workStartMin = 8 * 60,
    int workEndMin = 16 * 60,
    String phone = '',
  }) =>
      _createAccount(
        name: name,
        loginId: username,
        password: password,
        role: role,
        department: department,
        workStartMin: workStartMin,
        workEndMin: workEndMin,
        phone: phone,
      );

  /// إنشاء حساب زبون: يدخل برقم هاتفه ورمز الوصول (يصدره الأدمن/النظام).
  Future<void> createCustomerAccount({
    required String name,
    required String phone,
    required String accessCode,
    String contact = '',
  }) =>
      _createAccount(
        name: name,
        loginId: phone,
        password: accessCode,
        role: UserRole.customer,
        department: Department.none,
        phone: phone,
        contact: contact,
      );

  /// توليد رمز وصول رقمي (6 خانات) لحساب الزبون.
  static String generateAccessCode() {
    final r = Random();
    return List.generate(6, (_) => r.nextInt(10)).join();
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
