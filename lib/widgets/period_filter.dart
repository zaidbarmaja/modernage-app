import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';

/// فلتر فترة موحّد (كل الفترات / هذا الشهر / شهر محدّد) — يُستخدم في صفحات
/// الحسابات والتقارير والبصمة ليكون الفلتر متطابقًا. القيمة 'YYYY-MM' أو null.
class PeriodFilter extends StatelessWidget {
  /// التواريخ المتاحة (تُشتقّ منها قائمة الأشهر).
  final Iterable<DateTime?> dates;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;

  const PeriodFilter({
    super.key,
    required this.dates,
    required this.value,
    required this.onChanged,
    this.label = 'الفترة',
  });

  static final _fmt = DateFormat('MMMM yyyy', 'ar');

  /// مفتاح الشهر 'YYYY-MM' من تاريخ.
  static String ym(DateTime? d) =>
      d == null ? '' : '${d.year}-${d.month.toString().padLeft(2, '0')}';

  /// تسمية عربية للشهر (مثل: يونيو 2026).
  static String monthLabel(String ym) {
    final p = ym.split('-');
    return _fmt.format(DateTime(int.parse(p[0]), int.parse(p[1])));
  }

  /// هل يقع التاريخ ضمن الشهر المختار؟ (true دائمًا إذا month == null).
  static bool inMonth(DateTime? d, String? month) =>
      month == null ? true : ym(d) == month;

  @override
  Widget build(BuildContext context) {
    final currentYM = ym(DateTime.now());
    final months = <String>{};
    for (final d in dates) {
      final y = ym(d);
      if (y.isNotEmpty) months.add(y);
    }
    final list = months.toList()..sort((a, b) => b.compareTo(a)); // الأحدث أولاً
    // قيمة آمنة: تُهمل إن لم تعد متاحة في القائمة.
    final safe = (value == null || value == currentYM || list.contains(value))
        ? value
        : null;

    return DropdownButtonFormField<String?>(
      initialValue: safe,
      isExpanded: true,
      dropdownColor: AppColors.surfaceAlt,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_month),
      ),
      items: [
        const DropdownMenuItem<String?>(
            value: null, child: Text('كل الفترات')),
        DropdownMenuItem<String?>(
            value: currentYM, child: const Text('هذا الشهر')),
        ...list
            .where((m) => m != currentYM)
            .map((m) => DropdownMenuItem<String?>(
                value: m, child: Text(monthLabel(m)))),
      ],
      onChanged: onChanged,
    );
  }
}
