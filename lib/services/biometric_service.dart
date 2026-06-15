import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

/// نتيجة التحقق ببصمة الإصبع.
enum BioResult {
  /// تم التحقق بنجاح.
  success,

  /// فشل التحقق (بصمة خاطئة أو ألغى المستخدم).
  failed,

  /// الجهاز لا يدعم البصمة إطلاقًا (لا يوجد مستشعر/قفل شاشة).
  unavailable,

  /// الجهاز يدعم البصمة لكن لا توجد بصمة مسجّلة.
  notEnrolled,
}

/// خدمة بصمة الإصبع (تستخدم مستشعر الهاتف عبر local_auth).
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// هل يدعم الجهاز التحقق الحيوي (بصمة/وجه) مع قفل شاشة آمن؟
  static Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// يطلب من المستخدم وضع بصمته، ويعيد نتيجة واضحة.
  static Future<BioResult> authenticate(String reason) async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return BioResult.unavailable;

      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return ok ? BioResult.success : BioResult.failed;
    } on PlatformException catch (e) {
      if (e.code == auth_error.notAvailable ||
          e.code == auth_error.notEnrolled) {
        return BioResult.notEnrolled;
      }
      return BioResult.failed;
    } catch (_) {
      return BioResult.failed;
    }
  }
}
