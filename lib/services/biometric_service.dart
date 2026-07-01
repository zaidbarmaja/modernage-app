import 'package:flutter/services.dart' show PlatformException;
import 'package:local_auth/local_auth.dart';

/// نتيجة التحقّق بالبصمة:
/// • success: تحقّق الموظف ببصمته بنجاح.
/// • failed: فشل التحقّق أو ألغاه المستخدم (يُمنع تسجيل الحضور).
/// • unavailable: لا بصمة على الجهاز (لا نمنع كي لا يُحبَس موظف بلا بصمة مُسجّلة).
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
    } on PlatformException catch (_) {
      // خطأ نظام (لا جهاز/غير مُسجّل/مقفل) → لا نمنع التسجيل.
      return BioResult.unavailable;
    } catch (_) {
      return BioResult.unavailable;
    }
  }
}
