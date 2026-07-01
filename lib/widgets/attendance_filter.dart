import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';

/// فلتر البصمة: كل الأيام · هذا الشهر · اليوم · أمس · وباقي أيام الأسبوع (آخر 7
/// أيام). القيمة رمز نصّي: null=الكل، 'm:YYYY-MM'=شهر، 'd:YYYY-MM-DD'=يوم محدّد.
class AttendanceFilter extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const AttendanceFilter({super.key, required this.value, required this.onChanged});

  static final _dayFmt = DateFormat('EEEE d MMMM', 'ar');

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String ym(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  /// هل يطابق التاريخ الفلتر المختار؟
  static bool matches(DateTime? d, String? sel) {
    if (sel == null) return true;
    if (d == null) return false;
    if (sel.startsWith('m:')) return ym(d) == sel.substring(2);
    if (sel.startsWith('d:')) return dayKey(d) == sel.substring(2);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('كل الأيام')),
      DropdownMenuItem(value: 'm:${ym(today)}', child: const Text('هذا الشهر')),
    ];
    // اليوم، أمس، وباقي أيام الأسبوع (آخر 7 أيام).
    for (var i = 0; i < 7; i++) {
      final d = today.subtract(Duration(days: i));
      final label = i == 0
          ? 'اليوم — ${_dayFmt.format(d)}'
          : i == 1
              ? 'أمس — ${_dayFmt.format(d)}'
              : _dayFmt.format(d);
      items.add(DropdownMenuItem(
          value: 'd:${dayKey(d)}',
          child: Text(label, overflow: TextOverflow.ellipsis)));
    }
    final valid = items.map((e) => e.value).toSet();
    final safe = valid.contains(value) ? value : null;

    return DropdownButtonFormField<String?>(
      initialValue: safe,
      isExpanded: true,
      dropdownColor: AppColors.surfaceAlt,
      decoration: const InputDecoration(
        labelText: 'الفترة',
        prefixIcon: Icon(Icons.calendar_today),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}
