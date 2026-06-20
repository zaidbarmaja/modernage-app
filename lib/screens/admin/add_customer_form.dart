import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/ui.dart';

/// نموذج إضافة زبون من لوحة الإدارة: الاسم + رقم الهاتف + رمز الوصول.
/// يدخل الزبون لاحقاً برقم هاتفه ورمز الوصول هذا، ويرى مشاريعه فقط (قراءة فقط).
class AddCustomerForm extends StatefulWidget {
  const AddCustomerForm({super.key});

  @override
  State<AddCustomerForm> createState() => _AddCustomerFormState();
}

class _AddCustomerFormState extends State<AddCustomerForm> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _contact = TextEditingController();
  final _code = TextEditingController(text: AuthService.generateAccessCode());
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _contact.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _auth.createCustomerAccount(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        accessCode: _code.text.trim(),
        contact: _contact.text.trim(),
      );
      if (!mounted) return;
      // عرض بيانات الدخول للأدمن ليسلّمها للزبون.
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('تم إنشاء حساب الزبون ✓',
              style: TextStyle(color: AppColors.cream)),
          content: Text(
            'سلّم الزبون بيانات الدخول:\n\n'
            'رقم الهاتف: ${_phone.text.trim()}\n'
            'رمز الدخول: ${_code.text.trim()}',
            style: const TextStyle(color: AppColors.creamDim, height: 1.7),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('تم'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر إنشاء حساب الزبون.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة زبون')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'اسم الزبون',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'أدخل اسم الزبون' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.replaceAll(RegExp(r'\D'), '').length < 7)
                          ? 'أدخل رقم هاتف صحيح'
                          : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contact,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'بيانات التواصل (اختياري)',
                    hintText: 'العنوان، هاتف بديل، ملاحظات…',
                    prefixIcon: Icon(Icons.contacts_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'رمز الدخول — 4 أرقام (يُسلّم للزبون)',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    suffixIcon: IconButton(
                      tooltip: 'توليد رمز جديد',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => setState(
                          () => _code.text = AuthService.generateAccessCode()),
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
                const SizedBox(height: 26),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: AppColors.cream, strokeWidth: 2.2))
                      : const Icon(Icons.person_add),
                  label: const Text('إنشاء حساب الزبون'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
