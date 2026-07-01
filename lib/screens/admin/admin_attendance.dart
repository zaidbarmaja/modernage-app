import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/attendance.dart';
import '../../services/firestore_service.dart';
import '../../widgets/ui.dart';
import 'admin_attendance_edit.dart';

/// متابعة حضور كل الموظفين (للإدارة) — على النظام الجديد (users + attendance
/// بحقل uid): يعرض **جميع الموظفين** (تصميم/تنفيذ/محاسبة) حتى بلا سجلات، مع
/// حالة اليوم (داخل/انصرف/غائب) وإجمالي الساعات الإضافية، وبالضغط سجلّ الموظف.
class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  final _fs = FirestoreService();
  String _search = '';

  /// الموظفون = كل المستخدمين عدا الزبائن والمدير.
  static bool _isStaff(AppUser u) =>
      u.role != UserRole.customer && u.role != UserRole.admin;

  void _openDetail(AppUser u) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EmployeeAttendanceEdit(user: u)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: _fs.allUsers(),
      builder: (context, uSnap) {
        if (uSnap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (uSnap.hasError) {
          return const EmptyState(
              message: 'تعذّر تحميل الموظفين.', icon: Icons.error_outline);
        }
        final employees = (uSnap.data ?? const <AppUser>[])
            .where(_isStaff)
            .toList();

        return StreamBuilder<List<AttendanceRecord>>(
          stream: _fs.allAttendance(),
          builder: (context, aSnap) {
            final records = aSnap.data ?? const <AttendanceRecord>[];
            final todayKey = AttendanceRecord.dayKeyOf(DateTime.now());
            final todayByUid = <String, AttendanceRecord>{};
            final overtimeByUid = <String, int>{};
            for (final r in records) {
              if (r.dayKey == todayKey) todayByUid[r.uid] = r;
              overtimeByUid[r.uid] =
                  (overtimeByUid[r.uid] ?? 0) + r.overtimeMinutes;
            }

            var present = 0;
            for (final e in employees) {
              if (todayByUid.containsKey(e.uid)) present++;
            }
            final total = employees.length;
            final absent = total - present;

            var list = employees;
            final q = _search.trim();
            if (q.isNotEmpty) {
              list = list.where((e) => e.name.contains(q)).toList();
            }

            return ListView(
              padding: const EdgeInsets.all(14),
              children: [
                const PageHeader(
                  title: 'متابعة حضور الموظفين',
                  subtitle: 'كل الموظفين وحالة حضورهم اليوم (تلقائي بالموقع)',
                  icon: Icons.groups,
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.7,
                  children: [
                    StatTile(
                        value: '$total',
                        label: 'إجمالي الموظفين',
                        icon: Icons.badge),
                    StatTile(
                        value: '$present',
                        label: 'حضروا اليوم',
                        icon: Icons.event_available,
                        color: AppColors.success),
                    StatTile(
                        value: '$absent',
                        label: 'لم يحضروا اليوم',
                        icon: Icons.event_busy,
                        color: AppColors.warning),
                    StatTile(
                        value: '${records.length}',
                        label: 'إجمالي سجلات البصمة',
                        icon: Icons.fingerprint,
                        color: AppColors.oliveBright),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'ابحث عن موظف بالاسم',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: 12),
                if (list.isEmpty)
                  const EmptyState(
                      message: 'لا يوجد موظفون.', icon: Icons.group_off)
                else
                  ...list.map((e) {
                    final rec = todayByUid[e.uid];
                    final open = rec != null && rec.isOpen;
                    final (label, color) = open
                        ? ('داخل الآن', AppColors.success)
                        : rec != null
                            ? ('انصرف اليوم', AppColors.oliveBright)
                            : ('غائب اليوم', AppColors.warning);
                    final ot = overtimeByUid[e.uid] ?? 0;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.oliveDark,
                          child: Text(e.name.isNotEmpty ? e.name[0] : '؟',
                              style: const TextStyle(color: AppColors.cream)),
                        ),
                        title: Text(e.name.isEmpty ? 'موظف' : e.name,
                            style: const TextStyle(
                                color: AppColors.cream,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${e.role.labelAr}'
                            '${ot > 0 ? '  •  إضافي: ${Fmt.duration(ot)}' : ''}',
                            style:
                                const TextStyle(color: AppColors.creamDim)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                        onTap: () => _openDetail(e),
                      ),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }
}
