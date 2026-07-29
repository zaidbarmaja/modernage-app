import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../services/notifications.dart';
import '../../widgets/notifications_view.dart';
import '../../widgets/ui.dart';

/// إشعارات الإدارة: إرسال تنبيه لكل المستخدمين + استعراض كل الإشعارات.
class AdminNotificationsScreen extends StatefulWidget {
  final AppUser admin;
  const AdminNotificationsScreen({super.key, required this.admin});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('إرسال للجميع',
            style: TextStyle(color: AppColors.cream)),
        content: const Text('سيصل هذا الإشعار إلى كل المستخدمين. متابعة؟',
            style: TextStyle(color: AppColors.creamDim, height: 1.6)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.creamDim))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إرسال')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final n = await Notifications.broadcast(
        title: _title.text.trim(),
        body: _body.text.trim(),
        fromUid: widget.admin.uid,
        fromName: widget.admin.name,
      );
      if (mounted) {
        _title.clear();
        _body.clear();
        FocusScope.of(context).unfocus();
        showSnack(context, 'تم إرسال الإشعار إلى $n مستخدماً ✓');
      }
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر إرسال الإشعار.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: SectionCard(
                title: 'إرسال إشعار للجميع',
                icon: Icons.campaign,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _title,
                        decoration: const InputDecoration(
                          labelText: 'العنوان',
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'أدخل عنوان الإشعار'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _body,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'نص الإشعار',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.message_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'أدخل نص الإشعار'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _send,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: AppColors.cream, strokeWidth: 2.2))
                            : const Icon(Icons.send),
                        label: const Text('إرسال للكل'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('كل الإشعارات',
                    style: TextStyle(
                        color: AppColors.cream,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
            const Expanded(child: NotificationsView()),
          ],
        ),
      ),
    );
  }
}
