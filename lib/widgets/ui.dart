import 'package:flutter/material.dart';

import '../core/theme.dart';

/// أدوات واجهة مشتركة لتوحيد الشكل في كل الصفحات.

/// بطاقة بعنوان ومحتوى.
class SectionCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    this.title,
    this.icon,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: AppColors.oliveBright, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.cream,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// صف "عنوان: قيمة".
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.creamDim),
            const SizedBox(width: 8),
          ],
          Text('$label: ',
              style: const TextStyle(color: AppColors.creamDim, fontSize: 14)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.cream,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// مربع إحصائي (رقم + وصف) للبصمة والميزانيات.
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color? color;

  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.oliveBright;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(icon, color: c, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: c, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.creamDim, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// شريط نسبة إنجاز بعنوان ونسبة مئوية ولون يتدرّج مع التقدّم.
class ProgressBar extends StatelessWidget {
  final int percent; // 0..100
  final String label;
  final Color? color;

  const ProgressBar({
    super.key,
    required this.percent,
    this.label = 'نسبة الإنجاز',
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = percent.clamp(0, 100);
    final c = color ??
        (pct >= 100
            ? AppColors.success
            : pct >= 50
                ? AppColors.oliveBright
                : AppColors.warning);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style:
                      const TextStyle(color: AppColors.creamDim, fontSize: 13)),
            ),
            Text('$pct%',
                style: TextStyle(
                    color: c, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct / 100.0,
            minHeight: 9,
            backgroundColor: AppColors.surfaceAlt,
            valueColor: AlwaysStoppedAnimation<Color>(c),
          ),
        ),
      ],
    );
  }
}

/// حالة فارغة (لا توجد بيانات).
class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.creamDim),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.creamDim, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

/// مؤشر تحميل بسيط بلون اللوكو.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: AppColors.oliveBright),
      );
}

/// أدوات سريعة للرسائل.
void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : AppColors.oliveDark,
    ));
}

/// عنوان قسم داخل الصفحة.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.oliveGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.cream, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.cream,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!,
                      style: const TextStyle(
                          color: Color(0xFFE6EAF0), fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
