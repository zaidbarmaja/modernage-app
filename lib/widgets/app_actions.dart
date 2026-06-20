import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/app_user.dart';
import '../services/auth_controller.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'ui.dart';

/// إجراءات الحساب في شريط كل الصفحات: تغيير كلمة المرور + تسجيل الخروج.
/// أثناء انتحال الأدمن لحساب مستخدم، يتحوّل الزر إلى "العودة للإدارة".
class LogoutAction extends StatelessWidget {
  const LogoutAction({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.isImpersonating) {
      return IconButton(
        tooltip: 'العودة لحساب الإدارة',
        icon: const Icon(Icons.exit_to_app, color: AppColors.cream),
        onPressed: () => context.read<AuthController>().stopImpersonating(),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'الحساب',
      icon: const Icon(Icons.account_circle_outlined, color: AppColors.cream),
      color: AppColors.surfaceAlt,
      onSelected: (v) {
        if (v == 'profile') {
          final u = context.read<AuthController>().appUser;
          if (u != null) {
            showDialog<void>(
                context: context, builder: (_) => EditProfileDialog(user: u));
          }
        } else if (v == 'password') {
          showDialog<void>(
              context: context, builder: (_) => const ChangePasswordDialog());
        } else if (v == 'logout') {
          _confirmLogout(context);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'profile',
          child: Row(children: [
            Icon(Icons.badge_outlined, size: 20, color: AppColors.cream),
            SizedBox(width: 10),
            Text('تعديل معلوماتي', style: TextStyle(color: AppColors.cream)),
          ]),
        ),
        PopupMenuItem(
          value: 'password',
          child: Row(children: [
            Icon(Icons.lock_outline, size: 20, color: AppColors.cream),
            SizedBox(width: 10),
            Text('تغيير كلمة المرور', style: TextStyle(color: AppColors.cream)),
          ]),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(children: [
            Icon(Icons.logout, size: 20, color: AppColors.danger),
            SizedBox(width: 10),
            Text('تسجيل الخروج', style: TextStyle(color: AppColors.danger)),
          ]),
        ),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('تسجيل الخروج',
            style: TextStyle(color: AppColors.cream)),
        content: const Text('هل تريد تسجيل الخروج من التطبيق؟',
            style: TextStyle(color: AppColors.creamDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء',
                style: TextStyle(color: AppColors.creamDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('خروج', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<AuthController>().signOut();
    }
  }
}

/// حوار تغيير كلمة المرور للمستخدم الحالي (إعادة مصادقة بالحالية ثم تحديث).
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _auth.changeOwnPassword(_current.text, _new.text);
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, 'تم تغيير كلمة المرور ✓');
      }
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر تغيير كلمة المرور.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('تغيير كلمة المرور',
          style: TextStyle(color: AppColors.cream)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور الحالية',
                prefixIcon: Icon(Icons.lock_clock),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'أدخل كلمة المرور الحالية' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _new,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور الجديدة',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) => (v == null || v.length < 6)
                  ? '6 أحرف على الأقل'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'تأكيد كلمة المرور',
                prefixIcon: Icon(Icons.lock_reset),
              ),
              validator: (v) =>
                  (v != _new.text) ? 'كلمتا المرور غير متطابقتين' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('إلغاء',
              style: TextStyle(color: AppColors.creamDim)),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: AppColors.cream, strokeWidth: 2.2))
              : const Text('حفظ'),
        ),
      ],
    );
  }
}

/// حوار تعديل المعلومات الشخصية للمستخدم الحالي (الاسم/الهاتف/بيانات التواصل).
/// يحدّث ملفه ويعيد حساب مفاتيح الدخول كي يبقى الدخول بالاسم/الهاتف صحيحاً.
class EditProfileDialog extends StatefulWidget {
  final AppUser user;
  const EditProfileDialog({super.key, required this.user});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _fs = FirestoreService();
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _contact;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _phone = TextEditingController(text: widget.user.phone);
    _contact = TextEditingController(text: widget.user.contact);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final name = _name.text.trim();
      final phone = _phone.text.trim();
      await _fs.updateUser(widget.user.uid, {
        'name': name,
        'phone': phone,
        'contact': _contact.text.trim(),
        'loginNames': _auth.loginKeys(name, phone),
      });
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, 'تم تحديث معلوماتك ✓');
      }
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر تحديث المعلومات.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title:
          const Text('تعديل معلوماتي', style: TextStyle(color: AppColors.cream)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'الاسم',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'أدخل الاسم' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contact,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'بيانات التواصل (اختياري)',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.contacts_outlined),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('إلغاء',
              style: TextStyle(color: AppColors.creamDim)),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: AppColors.cream, strokeWidth: 2.2))
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
