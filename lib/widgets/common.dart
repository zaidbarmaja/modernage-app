import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../services/session.dart';
import '../theme.dart';

/// بطاقة مؤشر (KPI) — أيقونة + عنوان + قيمة، تتمدّد لتملأ عرض الخلية الأم.
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? accent;
  const KpiCard(this.label, this.value, {this.icon, this.accent, super.key});

  @override
  Widget build(BuildContext context) {
    final accentColor = accent ?? AppColors.green600;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.cream100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: accentColor),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: AppColors.textSoft, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.green900)),
        ],
      ),
    );
  }
}

/// شبكة متجاوبة: تُرتّب الأبناء في أعمدة متساوية العرض حسب المساحة المتاحة،
/// فلا تظهر صفوف متعرّجة (تُستخدم لبطاقات المؤشرات والأقسام).
class AutoGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;
  final double gap;
  const AutoGrid({
    required this.children,
    this.minTileWidth = 160,
    this.gap = 12,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final maxW = c.maxWidth;
      var cols = (maxW / (minTileWidth + gap)).floor();
      if (cols < 1) cols = 1;
      if (cols > children.length) cols = children.length.clamp(1, cols);
      // floorToDouble يمنع تجاوز سطر بكسور البكسل فيُسقط آخر عمود.
      final tileW = cols <= 1
          ? maxW
          : ((maxW - gap * (cols - 1)) / cols).floorToDouble();
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final ch in children) SizedBox(width: tileW, child: ch),
        ],
      );
    });
  }
}

/// عرض حالة التحميل (دوّارة + نص اختياري) — لتفادي الشاشة الفارغة أثناء الجلب.
class LoadingView extends StatelessWidget {
  final String? text;
  const LoadingView({this.text, super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (text != null) ...[
            const SizedBox(height: 14),
            Text(text!, style: const TextStyle(color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}

/// عرض رسالة (فارغ / خطأ) في منتصف الشاشة بدل الفراغ.
class MessageView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  const MessageView({
    required this.icon,
    required this.title,
    this.subtitle,
    this.color = AppColors.muted,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: color),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}

/// واجهة الخطأ الودّية المستخدمة في ErrorWidget.builder (بدل الشاشة الحمراء/البيضاء).
class FriendlyError extends StatelessWidget {
  final FlutterErrorDetails details;
  const FriendlyError({required this.details, super.key});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cream50,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.danger, size: 44),
              const SizedBox(height: 12),
              const Text('حدث خطأ غير متوقع في هذه الشاشة',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 8),
              Text(details.exceptionAsString(),
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// محتوى صفحة قابل للتمرير بهوامش موحّدة.
class PagePadding extends StatelessWidget {
  final Widget child;
  const PagePadding({required this.child, super.key});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: child,
      ),
    );
  }
}

/// عدّاد الأيام (− [حقل] +).
class DaysStepper extends StatelessWidget {
  final TextEditingController controller;
  const DaysStepper({required this.controller, super.key});

  void _bump(int delta) {
    final v = int.tryParse(controller.text) ?? 0;
    final next = (v + delta).clamp(0, 1 << 30);
    controller.text = next.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _btn('−', () => _bump(-1)),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 8),
        _btn('+', () => _bump(1)),
      ],
    );
  }

  Widget _btn(String s, VoidCallback onTap) => SizedBox(
        width: 44,
        height: 44,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
          child: Text(s, style: const TextStyle(fontSize: 20)),
        ),
      );
}

/// نافذة تسجيل دخول الموظف (تُستخدم في التصميم/التنفيذ/البصمة).
class EmployeeLogin extends StatefulWidget {
  final String subtitle;
  final Future<void> Function(EmployeeSession session) onSuccess;
  const EmployeeLogin({
    required this.onSuccess,
    this.subtitle = 'أدخل اسمك ورمزك السري لعرض مشاريعك الخاصة.',
    super.key,
  });

  @override
  State<EmployeeLogin> createState() => _EmployeeLoginState();
}

class _EmployeeLoginState extends State<EmployeeLogin> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final code = _code.text.trim();
    if (name.isEmpty || code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await Db.attemptLogin(name, code);
    if (!mounted) return;
    if (res.ok) {
      await widget.onSuccess(EmployeeSession(res.id!, res.name!));
    } else {
      setState(() {
        _busy = false;
        _error = res.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.green600,
                child: Text('ع',
                    style: TextStyle(color: Colors.white, fontSize: 22)),
              ),
              const SizedBox(height: 14),
              const Text('تسجيل دخول الموظف',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(widget.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSoft)),
              const SizedBox(height: 18),
              TextField(
                controller: _name,
                decoration: const InputDecoration(hintText: 'اسم الموظف'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'الرمز السري'),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('دخول'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شريط ترحيب الموظف + زر تبديل المستخدم.
class EmployeeBar extends StatelessWidget {
  final String name;
  final VoidCallback onLogout;
  final Widget? trailing;
  const EmployeeBar(
      {required this.name, required this.onLogout, this.trailing, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cream100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline, size: 18),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: Text('مرحبًا، $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          ?trailing,
          OutlinedButton(
            onPressed: onLogout,
            child: const Text('تبديل المستخدم'),
          ),
        ],
      ),
    );
  }
}
