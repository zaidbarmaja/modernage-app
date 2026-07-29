import 'package:flutter/services.dart' show PlatformException;
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';

/// نتيجة التحقّق بالبصمة:
/// • success: تحقّق الموظف ببصمته بنجاح.
/// • failed: فشل التحقّق أو ألغاه المستخدم أو أُقفلت البصمة (يُمنع تسجيل الحضور).
/// • unavailable: لا بصمة على الجهاز أصلاً (لا نمنع كي لا يُحبَس موظف بلا بصمة).
enum BioResult { success, failed, unavailable }

/// خدمة المصادقة بالبصمة/Face ID — للتحقّق من هوية الموظف قبل تسجيل الحضور أو
/// الانصراف. تتم بالكامل على الجهاز عبر نظام التشغيل؛ التطبيق لا يطّلع على
/// البصمة ولا يخزّنها.
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// يطلب بصمة الموظف. [reason] النص الظاهر في نافذة النظام.
  static Future<BioResult> verify(String reason) async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final available = await _auth.getAvailableBiometrics();
      // لا بصمة/تعرّف وجه مُسجّل على الجهاز → لا نمنع (نتابع بدون بصمة).
      if (!supported || !canCheck || available.isEmpty) {
        return BioResult.unavailable;
      }
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return ok ? BioResult.success : BioResult.failed;
    } on PlatformException catch (e) {
      // لا بصمة مُسجّلة / غير متاحة على الجهاز → لا نمنع.
      if (e.code == auth_error.notEnrolled ||
          e.code == auth_error.notAvailable ||
          e.code == auth_error.passcodeNotSet ||
          e.code == auth_error.otherOperatingSystem) {
        return BioResult.unavailable;
      }
      // القفل (محاولات خاطئة كثيرة) أو أي خطأ آخر → نمنع كي لا يُتجاوز التحقّق.
      return BioResult.failed;
    } catch (_) {
      // خطأ غير متوقّع → نمنع احتياطاً (لا نتجاوز البصمة).
      return BioResult.failed;
    }
  }
}
