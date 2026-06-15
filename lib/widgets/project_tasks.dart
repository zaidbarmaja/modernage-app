import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/time_utils.dart';

/// نسبة الإنجاز من قائمة المهام (done / total).
int taskProgressPercent(List<dynamic> tasks) {
  if (tasks.isEmpty) return 0;
  final done = tasks.where((t) => t is Map && t['done'] == true).length;
  return ((done / tasks.length) * 100).round();
}

/// قائمة مهام المشروع: مربع إنجاز + نص + تاريخ الإنشاء (+ أيام اختيارية للتنفيذ)
/// مع شريط نسبة الإنجاز. تُحدِّث مصفوفة `tasks` في مستند المشروع.
class ProjectTasks extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> reference;
  final List<dynamic> tasks;
  final bool editable; // إضافة/حذف/تبديل
  final bool showDays; // إظهار أيام لكل مهمة (التنفيذ)
  const ProjectTasks({
    required this.reference,
    required this.tasks,
    this.editable = true,
    this.showDays = false,
    super.key,
  });

  int get _doneCount =>
      tasks.where((t) => t is Map && t['done'] == true).length;

  int get _totalDays => tasks.fold<int>(0, (s, t) {
        final v = (t is Map) ? t['days'] : 0;
        return s + ((v is num) ? v.toInt() : 0);
      });

  List<Map<String, dynamic>> _asList() => [
        for (final t in tasks)
          if (t is Map) Map<String, dynamic>.from(t),
      ];

  /// يحفظ المهام، ويعدّل الأيام المتبقية للمشروع بمقدار [daysDelta]
  /// (أيام المهمة المضافة تُزاد على المجموع، والمحذوفة تُطرح منه).
  Future<void> _save(List<Map<String, dynamic>> next, {int daysDelta = 0}) async {
    final data = <String, dynamic>{'tasks': next};
    if (daysDelta != 0) {
      data['remainingDays'] = FieldValue.increment(daysDelta);
    }
    await reference.update(data);
  }

  Future<void> _toggle(int i, bool v) async {
    final list = _asList();
    if (i < list.length) {
      list[i]['done'] = v;
      await _save(list);
    }
  }

  Future<void> _remove(int i) async {
    final list = _asList();
    if (i < list.length) {
      final removed = list[i];
      final d = (removed['days'] is num) ? (removed['days'] as num).toInt() : 0;
      list.removeAt(i);
      await _save(list, daysDelta: -d);
    }
  }

  Future<void> _add(String text, int days) async {
    final list = _asList();
    list.add({
      'text': text,
      'done': false,
      'createdAt': DateTime.now().toIso8601String(),
      'days': days,
    });
    await _save(list, daysDelta: days);
  }

  @override
  Widget build(BuildContext context) {
    final total = tasks.length;
    final pct = taskProgressPercent(tasks);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : _doneCount / total,
                  minHeight: 10,
                  backgroundColor: AppColors.cream200,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.green600),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('$pct٪',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.green900)),
          ],
        ),
        const SizedBox(height: 4),
        Text('$_doneCount من $total مهمة منجزة',
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        if (showDays && _totalDays > 0) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.green100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
                'مجموع أيام المهام: $_totalDays يوم — تُضاف للأيام المتبقية وتنقص تلقائيًا كل يوم',
                style: const TextStyle(
                    color: AppColors.green800,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ],
        const SizedBox(height: 10),
        if (total == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('لا توجد مهام بعد.',
                style: TextStyle(color: AppColors.muted)),
          ),
        for (var i = 0; i < tasks.length; i++)
          if (tasks[i] is Map) _taskRow(i, tasks[i] as Map),
        if (editable) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _addDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة مهمة'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _taskRow(int i, Map t) {
    final done = t['done'] == true;
    final created = t['createdAt'];
    final days = (t['days'] is num) ? (t['days'] as num).toInt() : 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: done ? AppColors.green100 : AppColors.cream50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Checkbox(
            value: done,
            onChanged: editable ? (v) => _toggle(i, v ?? false) : null,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t['text'] ?? ''}',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration:
                            done ? TextDecoration.lineThrough : null,
                        color: done ? AppColors.muted : AppColors.text)),
                Row(
                  children: [
                    if (created != null && '$created'.isNotEmpty)
                      Text('أُنشئت: ${ArDate.dateOnly(created)}',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 11)),
                    if (showDays && days > 0) ...[
                      const SizedBox(width: 8),
                      Text('• $days يوم',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (editable)
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: AppColors.danger),
              onPressed: () => _remove(i),
            ),
        ],
      ),
    );
  }

  Future<void> _addDialog(BuildContext context) async {
    final text = TextEditingController();
    final days = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إضافة مهمة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: text,
                decoration:
                    const InputDecoration(labelText: 'المهمة / الملاحظة'),
              ),
              if (showDays) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: days,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'عدد الأيام (اختياري)'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('إضافة')),
          ],
        ),
      ),
    );
    if (ok == true && text.text.trim().isNotEmpty) {
      await _add(text.text.trim(), int.tryParse(days.text.trim()) ?? 0);
    }
  }
}

/// شارة حالة المشروع بلون مميّز.
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = status.isEmpty ? 'قيد التنفيذ' : status;
    Color bg, fg;
    if (s.contains('معلّق') || s.contains('معلق')) {
      bg = const Color(0xFFFBE7C6);
      fg = const Color(0xFF9A6700);
    } else if (s.contains('منجز') || s.contains('مكتمل')) {
      bg = AppColors.green100;
      fg = AppColors.green700;
    } else {
      bg = AppColors.cream200;
      fg = AppColors.textSoft;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(s,
          style: TextStyle(
              color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// أزرار اختيار حالة المشروع (قيد التنفيذ / معلّق / منجز).
class StatusSelector extends StatelessWidget {
  static const statuses = ['قيد التنفيذ', 'معلّق', 'منجز'];
  final String current;
  final ValueChanged<String> onChanged;
  const StatusSelector(
      {required this.current, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) {
    final cur = current.isEmpty ? 'قيد التنفيذ' : current;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in statuses)
          ChoiceChip(
            label: Text(s),
            selected: cur == s,
            onSelected: (_) => onChanged(s),
          ),
      ],
    );
  }
}
