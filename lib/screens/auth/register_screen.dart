import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/ui.dart';

/// إنشاء حساب: الاسم + رقم الهاتف + كلمة المرور.
/// يُسجَّل المستخدم كـ "زبون" تلقائياً، وتغيّر الإدارة دوره لاحقاً.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _auth.registerFirstAdmin(
        name: _name.text,
        username: _name.text,
        password: _password.text,
      );
      if (mounted) {
        Navigator.of(context).pop(); // يرجع لشاشة الدخول والتوجيه يتم تلقائياً
      }
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر إنشاء الحساب.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعداد حساب المدير')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x33E9E3CF)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.oliveBright),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'هذا الإعداد لأول مرة فقط: يصبح هذا الحساب هو «المدير». '
                          'بعده تُنشأ حسابات الموظفين من لوحة الإدارة حصراً.',
                          style: TextStyle(
                              color: AppColors.creamDim, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'أدخل الاسم' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'رمز الدخول — 4 أرقام',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.length != 4 || int.tryParse(t) == null) {
                      return 'رمز الدخول 4 أرقام';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد الرمز',
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                  validator: (v) =>
                      v != _password.text ? 'الرمز غير متطابق' : null,
                ),
                const SizedBox(height: 26),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _register,
                  icon: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: AppColors.cream, strokeWidth: 2.4),
                        )
                      : const Icon(Icons.person_add),
                  label: const Text('إنشاء الحساب'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
