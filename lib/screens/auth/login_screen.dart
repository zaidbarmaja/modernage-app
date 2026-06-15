import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../theme.dart';
import '../../services/auth_controller.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/ui.dart';
import 'register_screen.dart';

/// شاشة تسجيل الدخول الموحّدة (T-1.1):
/// دخول الإدارة والمصمم وموظف التنفيذ برقم الهاتف وكلمة المرور، مع تحقّق من
/// المدخلات ورسائل خطأ عربية واضحة. التوجيه حسب الدور يتم تلقائياً عبر
/// AuthGate ← RoleRouter بعد نجاح الدخول.
///
/// الشاشة مستقلّة بصرياً (خلفية خضراء داكنة بهوية الشعار) لتظهر بتباين عالٍ
/// بغضّ النظر عن ثيم التطبيق الفاتح.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _obscure = true;

  // مدخل تطوير مؤقّت: أكواد دخول محلية لكل دور (تُزال قبل الإطلاق).
  static const _devLogins = <String, UserRole>{
    'admin': UserRole.admin,
    'customer': UserRole.customer,
    'design': UserRole.designEmployee,
    'exec': UserRole.executionEmployee,
    'accounting': UserRole.accounting,
  };

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    // مدخل تطوير مؤقّت: دخول بأي دور بدون Firebase Auth (الاسم = كلمة المرور).
    final code = _phone.text.trim().toLowerCase();
    if (_devLogins.containsKey(code) &&
        _password.text.trim().toLowerCase() == code) {
      context.read<AuthController>().loginLocalRole(_devLogins[code]!);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _auth.signIn(_phone.text, _password.text);
      // النجاح: AuthGate يلتقط تغيّر الجلسة ويوجّه حسب الدور تلقائياً.
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showSnack(context, 'تعذّر تسجيل الدخول. حاول مرة أخرى.', error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validateIdentifier(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'أدخل اسم الدخول';
    if (t.length < 2) return 'اسم الدخول قصير جداً';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'أدخل كلمة المرور';
    if (v.length < 6) return 'كلمة المرور 6 أحرف على الأقل';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.green900,
              AppColors.green800,
              AppColors.green700,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLogo(size: 104),
                      const SizedBox(height: 18),
                      const Text(
                        'عصر الحداثة',
                        style: TextStyle(
                          color: AppColors.cream50,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'تسجيل الدخول إلى حسابك',
                        style:
                            TextStyle(color: AppColors.cream300, fontSize: 14),
                      ),
                      const SizedBox(height: 30),
                      _field(
                        controller: _phone,
                        label: 'الاسم',
                        hint: 'اسمك أو رقم هاتفك',
                        icon: Icons.person_outline,
                        textInputAction: TextInputAction.next,
                        validator: _validateIdentifier,
                      ),
                      const SizedBox(height: 16),
                      _field(
                        controller: _password,
                        label: 'كلمة المرور',
                        hint: '••••••',
                        icon: Icons.lock_outline,
                        obscure: _obscure,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _login(),
                        validator: _validatePassword,
                        suffix: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.muted,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.green500,
                            foregroundColor: AppColors.cream50,
                            disabledBackgroundColor: AppColors.green600,
                          ),
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    color: AppColors.cream50,
                                    strokeWidth: 2.4,
                                  ),
                                )
                              : const Text(
                                  'دخول',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                ),
                        child: const Text(
                          'إعداد حساب المدير (أول مرة)',
                          style: TextStyle(
                            color: AppColors.cream300,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'للتجربة (الاسم = كلمة المرور):\n'
                        'admin · customer · design · exec · accounting',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: AppColors.green400, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscure = false,
    bool ltr = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, right: 4),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.cream100,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          textDirection: ltr ? TextDirection.ltr : null,
          style: const TextStyle(color: AppColors.text, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.muted),
            prefixIcon: Icon(icon, color: AppColors.green600),
            suffixIcon: suffix,
            filled: true,
            fillColor: AppColors.cream50,
            errorStyle: const TextStyle(
              color: AppColors.dangerSoft,
              fontWeight: FontWeight.w600,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.green400, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.danger, width: 1.8),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
