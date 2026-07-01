import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/attendance.dart';
import '../../services/firestore_service.dart';
import '../../widgets/ui.dart';

/// شاشة سجل حضور موظف واحد (للإدارة): عرض السجلات + **تعديل/إضافة/حذف** مواعيد
/// الدخول والخروج يدويًا على النظام الجديد (attendance بحقل uid وTimestamp).
class EmployeeAttendanceEdit extends StatelessWidget {
  final AppUser user;
  const EmployeeAttendanceEdit({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return Scaffold(
      appBar: AppBar(
        title: Text('حضور: ${user.name}'),
        actions: [
          IconButton(
            tooltip: 'إضافة سجل يدوي',
            icon: const Icon(Icons.add),
            onPressed: () => _dialog(context, fs),
          ),
        ],
      ),
      body: StreamBuilder<List<AttendanceRecord>>(
        stream: fs.attendanceForUser(user.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snap.hasError) {
            return const EmptyState(
                message: 'تعذّر تحميل السجل.', icon: Icons.error_outline);
          }
          final recs = snap.data ?? const <AttendanceRecord>[];
          if (recs.isEmpty) {
            return Column(
              children: [
                const Expanded(
                  child: EmptyState(
                      message: 'لا توجد سجلات حضور لهذا الموظف.',
                      icon: Icons.event_busy),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _dialog(context, fs),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة سجل يدوي'),
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final r in recs)
                Card(
                  child: ListTile(
                    leading: Icon(
                        r.isOpen ? Icons.login : Icons.check_circle_outline,
                        color: r.isOpen
                            ? AppColors.success
                            : AppColors.oliveBright),
                    title: Text(Fmt.date(r.checkIn),
                        style: const TextStyle(
                            color: AppColors.cream,
                            fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'دخول ${Fmt.time(r.checkIn)}  •  خروج '
                      '${r.checkOut == null ? 'داخل الآن' : Fmt.time(r.checkOut)}'
                      '${r.checkOut == null ? '' : '\nعمل: ${Fmt.duration(r.workedMinutes)}  •  إضافي: ${Fmt.duration(r.overtimeMinutes)}'}',
                      style: const TextStyle(
                          color: AppColors.creamDim, height: 1.5),
                    ),
                    isThreeLine: r.checkOut != null,
                    trailing: IconButton(
                      icon:
                          const Icon(Icons.edit, color: AppColors.oliveBright),
                      tooltip: 'تعديل',
                      onPressed: () => _dialog(context, fs, r),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// حوار إضافة/تعديل سجل: يختار وقت الدخول والخروج ويحفظ على النظام الجديد.
  Future<void> _dialog(BuildContext context, FirestoreService fs,
      [AttendanceRecord? existing]) async {
    final isNew = existing == null;
    DateTime? ci = existing?.checkIn ?? DateTime.now();
    DateTime? co = existing?.checkOut;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        Future<void> pick(bool isIn) async {
          final base = (isIn ? ci : co) ?? DateTime.now();
          final d = await showDatePicker(
              context: ctx,
              initialDate: base,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100));
          if (d == null || !ctx.mounted) return;
          final t = await showTimePicker(
              context: ctx, initialTime: TimeOfDay.fromDateTime(base));
          if (t == null) return;
          final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
          setLocal(() => isIn ? ci = dt : co = dt);
        }

        String fmt(DateTime? dt) =>
            dt == null ? '—' : '${Fmt.date(dt)} · ${Fmt.time(dt)}';

        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(isNew ? 'إضافة سجل حضور' : 'تعديل سجل الحضور',
              style: const TextStyle(color: AppColors.cream)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('وقت الدخول',
                    style: TextStyle(color: AppColors.creamDim, fontSize: 13)),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                    onPressed: () => pick(true),
                    icon: const Icon(Icons.login, size: 16),
                    label: Text(fmt(ci))),
                const SizedBox(height: 12),
                const Text('وقت الخروج',
                    style: TextStyle(color: AppColors.creamDim, fontSize: 13)),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                    onPressed: () => pick(false),
                    icon: const Icon(Icons.logout, size: 16),
                    label: Text(co == null ? 'لا يوجد (داخل الآن)' : fmt(co))),
                if (co != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setLocal(() => co = null),
                      child: const Text('مسح وقت الخروج'),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            if (!isNew)
              TextButton(
                onPressed: () async {
                  await fs.deleteAttendance(existing.id);
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
                      final checkInAt = ci!;
                      final record = AttendanceRecord(
                        id: '',
                        uid: user.uid,
                        userName: user.name,
                        department: user.department,
                        workStartMin:
                            user.workStartMin ?? AppUser.defaultStartMin,
                        workEndMin: user.workEndMin ?? AppUser.defaultEndMin,
                        checkIn: checkInAt,
                        checkOut: co,
                      );
                      // إن تغيّر اليوم عند التعديل يتغيّر معرّف المستند — نحذف القديم.
                      final newId =
                          '${user.uid}_${AttendanceRecord.dayKeyOf(checkInAt)}';
                      await fs.checkIn(record);
                      if (!isNew && existing.id != newId) {
                        await fs.deleteAttendance(existing.id);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              child: Text(isNew ? 'إضافة' : 'حفظ'),
            ),
          ],
        );
      }),
    );
  }
}
