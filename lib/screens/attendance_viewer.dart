import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../theme.dart';
import '../utils/time_utils.dart';
import '../widgets/common.dart';

/// صفحة إدارية: أسماء الموظفين الذين سجّلوا البصمة في يوم محدّد (الافتراضي اليوم)
/// مع إمكانية اختيار تواريخ سابقة. وعند [canManage] يمكن للمدير إضافة/تعديل
/// سجلّ الدخول والخروج لأي موظف (الموظف نفسه لا يملك هذه الصلاحية).
class AttendanceViewerScreen extends StatefulWidget {
  final bool canManage;
  const AttendanceViewerScreen({this.canManage = false, super.key});
  @override
  State<AttendanceViewerScreen> createState() => _AttendanceViewerScreenState();
}

class _AttendanceViewerScreenState extends State<AttendanceViewerScreen> {
  DateTime _date = DateTime.now();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _employees = [];

  @override
  void initState() {
    super.initState();
    if (widget.canManage) {
      Db.employees.get().then((s) {
        if (mounted) setState(() => _employees = s.docs);
      }).catchError((_) {});
    }
  }

  bool get _isToday {
    final n = DateTime.now();
    return _date.year == n.year && _date.month == n.month && _date.day == n.day;
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (p != null) setState(() => _date = p);
  }

  @override
  Widget build(BuildContext context) {
    final dayKey = WorkTime.dateKey(_date);
    return Scaffold(
      appBar: AppBar(title: const Text('بصمات الموظفين')),
      floatingActionButton: widget.canManage
          ? FloatingActionButton.extended(
              onPressed: _pickEmployeeToAdd,
              icon: const Icon(Icons.add),
              label: const Text('إضافة بصمة يدوية'),
            )
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: Db.attendance.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const MessageView(
                icon: Icons.cloud_off,
                title: 'تعذّر تحميل البصمات',
                color: AppColors.danger);
          }
          if (!snap.hasData) return const LoadingView();
          final recs = snap.data!.docs
              .where((r) => WorkTime.attendanceDateKey(r.data()) == dayKey)
              .toList()
            ..sort((a, b) {
              final ca =
                  DateTime.tryParse('${a.data()['checkIn']}') ?? DateTime(0);
              final cb =
                  DateTime.tryParse('${b.data()['checkIn']}') ?? DateTime(0);
              return ca.compareTo(cb);
            });

          return PagePadding(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== شريط التاريخ =====
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.green800,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fingerprint,
                          color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_isToday ? 'بصمات اليوم' : 'بصمات يوم محدّد',
                                style: const TextStyle(
                                    color: AppColors.cream200, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(ArDate.fullArabicDate(_date),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      Text('${recs.length} موظف',
                          style: const TextStyle(color: AppColors.cream200)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event, size: 18),
                      label: const Text('اختر تاريخًا'),
                    ),
                    const SizedBox(width: 8),
                    if (!_isToday)
                      OutlinedButton(
                        onPressed: () => setState(() => _date = DateTime.now()),
                        child: const Text('اليوم'),
                      ),
                  ],
                ),
                if (widget.canManage) ...[
                  const SizedBox(height: 8),
                  const Text('اضغط على بطاقة موظف لتعديل دخوله/خروجه.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                if (recs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: MessageView(
                      icon: Icons.event_busy,
                      title: 'لا توجد بصمات في هذا اليوم',
                      subtitle: 'اختر تاريخًا آخر لعرض بصماته.',
                    ),
                  )
                else
                  AutoGrid(
                    minTileWidth: 300,
                    gap: 12,
                    children: [for (final r in recs) _card(r)],
                  ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final st = WorkTime.stats(d);
    final open = st.open;
    final name = (d['name'] ?? '').toString();
    final loc = (d['locationName'] ?? '').toString();
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    open ? AppColors.green100 : AppColors.cream100,
                child: Text(name.isEmpty ? 'ع' : name.characters.first,
                    style: const TextStyle(
                        color: AppColors.green700,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: open ? AppColors.green100 : AppColors.cream200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(open ? 'داخل الآن' : 'انصرف',
                    style: const TextStyle(fontSize: 11)),
              ),
              if (widget.canManage) ...[
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 16, color: AppColors.green700),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('دخول: ${ArDate.timeOnly(d['checkIn'])}'),
              _chip(open
                  ? 'خروج: —'
                  : 'خروج: ${ArDate.timeOnly(d['checkOut'])}'),
              if (!open)
                _chip('عمل: ${WorkTime.minutesToText(st.worked)}',
                    color: AppColors.green100),
              if (st.late > 0)
                _chip('تأخير: ${WorkTime.minutesToText(st.late)}',
                    color: AppColors.dangerSoft),
            ],
          ),
          if (loc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on,
                    size: 14, color: AppColors.muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(loc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
    if (!widget.canManage) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _recordDialog(doc: doc),
      child: card,
    );
  }

  Widget _chip(String text, {Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color ?? AppColors.cream100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );

  // ===== اختيار موظف لإضافة سجل يدوي =====
  Future<void> _pickEmployeeToAdd() async {
    if (_employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد موظفون.')));
      return;
    }
    final chosen = await showDialog<QueryDocumentSnapshot<Map<String, dynamic>>>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SimpleDialog(
          title: const Text('اختر الموظف'),
          children: [
            for (final e in _employees)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, e),
                child: Text('${e.data()['name'] ?? ''}'),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      _recordDialog(
          newEmployeeId: chosen.id, newEmployeeName: '${chosen.data()['name'] ?? ''}');
    }
  }

  /// نافذة إضافة/تعديل سجل بصمة (للمدير فقط).
  Future<void> _recordDialog({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
    String? newEmployeeId,
    String? newEmployeeName,
  }) async {
    final data = doc?.data() ?? {};
    final isNew = doc == null;
    DateTime? ci = isNew
        ? DateTime(_date.year, _date.month, _date.day, 8, 0)
        : DateTime.tryParse('${data['checkIn']}');
    DateTime? co = data['checkOut'] == null
        ? null
        : DateTime.tryParse('${data['checkOut']}');
    final noteC = TextEditingController(text: data['note']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        Future<void> pick(bool isIn) async {
          final base = (isIn ? ci : co) ?? DateTime.now();
          final dd = await showDatePicker(
            context: ctx,
            initialDate: base,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (dd == null || !ctx.mounted) return;
          final t = await showTimePicker(
              context: ctx, initialTime: TimeOfDay.fromDateTime(base));
          if (t == null) return;
          final dt = DateTime(dd.year, dd.month, dd.day, t.hour, t.minute);
          setLocal(() {
            if (isIn) {
              ci = dt;
            } else {
              co = dt;
            }
          });
        }

        String fmt(DateTime? dt) => dt == null
            ? '—'
            : '${ArDate.dateOnly(dt)} · ${ArDate.timeOnly(dt)}';

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(isNew
                ? 'إضافة سجل لـ ${newEmployeeName ?? ''}'
                : 'تعديل سجل ${data['name'] ?? ''}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('وقت الدخول', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () => pick(true),
                    icon: const Icon(Icons.login, size: 16),
                    label: Text(fmt(ci)),
                  ),
                  const SizedBox(height: 12),
                  const Text('وقت الخروج', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () => pick(false),
                    icon: const Icon(Icons.logout, size: 16),
                    label: Text(co == null ? 'لا يوجد (داخل الآن)' : fmt(co)),
                  ),
                  if (co != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setLocal(() => co = null),
                        child: const Text('مسح وقت الخروج'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteC,
                    decoration: const InputDecoration(labelText: 'ملاحظة'),
                  ),
                ],
              ),
            ),
            actions: [
              if (!isNew)
                TextButton(
                  onPressed: () async {
                    await doc.reference.delete();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('حذف',
                      style: TextStyle(color: AppColors.danger)),
                ),
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: ci == null
                    ? null
                    : () async {
                        if (isNew) {
                          await Db.attendance.add({
                            'name': newEmployeeName ?? '',
                            'employeeId': newEmployeeId ?? '',
                            'checkIn': ci!.toIso8601String(),
                            'checkOut': co?.toIso8601String(),
                            'note': noteC.text.trim(),
                            'method': 'manual',
                            'workStart': WorkTime.workStartMin,
                            'workEnd': WorkTime.workEndMin,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        } else {
                          await Db.updateAttendanceRecord(
                            doc.id,
                            checkInIso: ci!.toIso8601String(),
                            checkOutIso: co?.toIso8601String(),
                            note: noteC.text.trim(),
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                child: Text(isNew ? 'إضافة' : 'حفظ'),
              ),
            ],
          ),
        );
      }),
    );
  }
}
