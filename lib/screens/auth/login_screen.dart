import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_login.dart';
import '../../core/theme.dart';
import '../../services/auth_controller.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/ui.dart';
import '../legal/privacy_policy_screen.dart';

/// شاشة تسجيل الدخول الموحّدة (T-1.1) — تصميم عصري بهوية التطبيق الزيتونية:
/// شعار + بطاقة دخول مرتفعة، مع إظهار/إخفاء كلمة المرور، "تذكّرني"،
/// و"نسيت كلمة المرور؟". التوجيه حسب الدور تلقائي عبر AuthGate ← RoleRouter.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _remember = true;
  bool _agreed = false; // الموافقة على سياسة الخصوصية (شرط للدخول)

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_agreed) {
      showSnack(context, 'يجب الموافقة على سياسة الخصوصية أولاً.', error: true);
      return;
    }
    final auth = context.read<AuthController>();
    setState(() => _loading = true);
    try {
      if (!_formKey.currentState!.validate()) return;
      // دخول المدير: إن طابق الاسمُ اسمَ المدير، تُمرَّر كلمة المرور المُدخلة إلى
      // Firebase للتحقّق منها مباشرةً (لا تُقارَن بأي قيمة مخزّنة في الكود).
      if (_phone.text.trim() == AppLogin.username) {
        await auth.loginCodeAdmin(_password.text, remember: _remember);
        return;
      }
      // بقية الحسابات: كلمة مرور Firestore (ضبطها المدير) أو مسار Firebase Auth —
      // يتولّاه AuthController.login. AuthGate يوجّه حسب الدور.
      await auth.login(_phone.text, _password.text, remember: _remember);
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

  /// يفتح سياسة الخصوصية المنشورة على الويب في المتصفّح، ويعود للنسخة داخل
  /// التطبيق إن تعذّر فتح الرابط (بلا إنترنت مثلاً).
  Future<void> _openPrivacy() async {
    final uri = Uri.parse(PrivacyPolicyScreen.publicUrl);
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // نتجاهل ونعرض النسخة داخل التطبيق كبديل.
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  void _forgotPassword() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('نسيت كلمة المرور؟',
            style: TextStyle(color: AppColors.cream)),
        content: const Text(
          'لإعادة تعيين كلمة مرورك تواصل مع الإدارة لإصدار كلمة مرور جديدة.\n'
          'وبعد الدخول يمكنك تغييرها في أي وقت من قائمة الحساب أعلى الشاشة.',
          style: TextStyle(color: AppColors.creamDim, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً',
                style: TextStyle(color: AppColors.oliveBright)),
          ),
        ],
      ),
    );
  }

  String? _validateIdentifier(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'أدخل اسم الدخول';
    if (t.length < 2) return 'اسم الدخول قصير جداً';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'أدخل كلمة المرور';
    // الحدّ الأدنى ٤ ليقبل رمز الزبون الرباعي (كلمات الموظفين أطول أصلاً).
    if (v.length < 4) return 'كلمة المرور 4 خانات على الأقل';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.surface,
              AppColors.oliveDark,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _brand(),
                    const SizedBox(height: 22),
                    _card(),
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: _openPrivacy,
                      icon: const Icon(Icons.privacy_tip_outlined, size: 16),
                      label: const Text('سياسة الخصوصية',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.creamDim),
                    ),
                    const SizedBox(height: 4),
                    const Text('الإصدار 1.0  •  عصر الحداثة',
                        style:
                            TextStyle(color: AppColors.creamDim, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.olive.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: AppColors.olive.withValues(alpha: 0.35),
                blurRadius: 30,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo.png',
            width: 210,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const AppLogo(size: 96),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'M O D E R N A G E',
          style: TextStyle(
            color: AppColors.oliveBright.withValues(alpha: 0.9),
            fontSize: 12,
            letterSpacing: 4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x26ECEFE1)),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('تسجيل الدخول',
                style: TextStyle(
                    color: AppColors.cream,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('أدخل بياناتك للوصول إلى حسابك',
                style: TextStyle(color: AppColors.creamDim, fontSize: 13)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _phone,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppColors.cream),
              decoration: const InputDecoration(
                labelText: 'الاسم',
                hintText: 'اسمك أو رقم هاتفك',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: _validateIdentifier,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _login(),
              style: const TextStyle(color: AppColors.cream),
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.creamDim),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: _validatePassword,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Switch(
                  value: _remember,
                  onChanged: (v) => setState(() => _remember = v),
                  activeThumbColor: AppColors.cream,
                  activeTrackColor: AppColors.olive,
                ),
                const Text('تذكّرني',
                    style: TextStyle(color: AppColors.creamDim, fontSize: 13)),
                const Spacer(),
                TextButton(
                  onPressed: _loading ? null : _forgotPassword,
                  child: const Text('نسيت كلمة المرور؟',
                      style: TextStyle(
                          color: AppColors.oliveBright, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // شرط الموافقة على سياسة الخصوصية قبل الدخول.
            Row(
              children: [
                Checkbox(
                  value: _agreed,
                  onChanged: (v) => setState(() => _agreed = v ?? false),
                  activeColor: AppColors.olive,
                  checkColor: AppColors.cream,
                ),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('أوافق على ',
                          style: TextStyle(
                              color: AppColors.creamDim, fontSize: 13)),
                      InkWell(
                        onTap: _openPrivacy,
                        child: const Text('سياسة الخصوصية',
                            style: TextStyle(
                                color: AppColors.oliveBright,
                                fontSize: 13,
                                decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_loading || !_agreed) ? null : _login,
                icon: _loading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.login),
                label: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: AppColors.cream, strokeWidth: 2.4))
                    : const Text('دخول',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
