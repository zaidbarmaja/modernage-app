import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/daily_report.dart';
import '../../services/firestore_service.dart';
import '../../widgets/attendance_filter.dart';
import '../../widgets/ui.dart';

/// شاشة التقارير (تقارير فقط): قائمة الموظفين واحدًا أسفل الآخر، وبالضغط على
/// موظف تظهر تقاريره من الأحدث للأقدم، مع فلتر اختيار الموظف ونطاق تاريخ من/إلى.
class AdminReportsView extends StatefulWidget {
  const AdminReportsView({super.key});

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> {
  final _fs = FirestoreService();
  String? _uid; // الموظف المختار (null = عرض قائمة الموظفين)
  String _selectedName = '';
  DateTime? _from;
  DateTime? _to;
  String? _sel; // فلتر الفترة (مثل البصمة): null / 'm:YYYY-MM' / 'd:YYYY-MM-DD'

  /// فلتر الفترة (نفس فلتر البصمة): كل الأيام/هذا الشهر/اليوم/أمس/باقي الأسبوع.
  Widget _periodFilter() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AttendanceFilter(
          value: _sel,
          onChanged: (v) => setState(() => _sel = v),
        ),
      );

  bool _passes(DateTime d) => _inRange(d) && AttendanceFilter.matches(d, _sel);

  Future<void> _pickDate(bool from) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => from ? _from = picked : _to = picked);
    }
  }

  bool _inRange(DateTime d) {
    if (_from != null &&
        d.isBefore(DateTime(_from!.year, _from!.month, _from!.day))) {
      return false;
    }
    if (_to != null &&
        d.isAfter(DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59))) {
      return false;
    }
    return true;
  }

  static String _fmtD(DateTime? d) => d == null ? 'الكل' : Fmt.date(d);

  static bool _isStaff(AppUser u) =>
      u.role != UserRole.customer && u.role != UserRole.admin;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: _fs.allUsers(),
      builder: (context, uSnap) {
        if (uSnap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final employees =
            (uSnap.data ?? const <AppUser>[]).where(_isStaff).toList();
        return StreamBuilder<List<DailyReport>>(
          stream: _fs.allDailyReports(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const EmptyState(
                  message: 'تعذّر تحميل التقارير.', icon: Icons.error_outline);
            }
            final all = snap.data ?? const <DailyReport>[];
            return _uid == null
                ? _employeesView(employees, all)
                : _employeeReports(all);
          },
        );
      },
    );
  }

  Widget _dateFilter() {
    return SectionCard(
      title: 'تصفية بالتاريخ',
      icon: Icons.filter_alt,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickDate(true),
              icon: const Icon(Icons.event, size: 18),
              label: Text('من: ${_fmtD(_from)}'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickDate(false),
              icon: const Icon(Icons.event, size: 18),
              label: Text('إلى: ${_fmtD(_to)}'),
            ),
          ),
          if (_from != null || _to != null)
            IconButton(
              tooltip: 'مسح الفلتر',
              icon: const Icon(Icons.close, color: AppColors.creamDim),
              onPressed: () => setState(() {
                _from = null;
                _to = null;
              }),
            ),
        ],
      ),
    );
  }

  /// قائمة **كل الموظفين** (واحد أسفل الآخر) مع عدد تقارير كلٍّ منهم (حتى صفر).
  Widget _employeesView(List<AppUser> employees, List<DailyReport> all) {
    final counts = <String, int>{};
    for (final r in all) {
      if (r.uid.isEmpty) continue;
      if (_passes(r.date)) counts[r.uid] = (counts[r.uid] ?? 0) + 1;
    }
    final emps = [...employees]..sort((a, b) => a.name.compareTo(b.name));

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const PageHeader(
          title: 'تقارير الموظفين',
          subtitle: 'كل الموظفين — اختر موظفًا لعرض تقاريره من الأحدث',
          icon: Icons.event_note,
        ),
        const SizedBox(height: 12),
        _periodFilter(),
        _dateFilter(),
        const SizedBox(height: 12),
        if (emps.isEmpty)
          const EmptyState(
              message: 'لا يوجد موظفون.', icon: Icons.group_off)
        else
          ...emps.map((e) {
            final name = e.name.isEmpty ? 'موظف' : e.name;
            final n = counts[e.uid] ?? 0;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.oliveDark,
                  child: Text(name.isNotEmpty ? name[0] : '؟',
                      style: const TextStyle(color: AppColors.cream)),
                ),
                title: Text(name,
                    style: const TextStyle(
                        color: AppColors.cream, fontWeight: FontWeight.bold)),
                subtitle: Text('${e.role.labelAr}  •  $n تقرير',
                    style: const TextStyle(color: AppColors.creamDim)),
                trailing:
                    const Icon(Icons.chevron_left, color: AppColors.creamDim),
                onTap: () => setState(() {
                  _uid = e.uid;
                  _selectedName = name;
                }),
              ),
            );
          }),
      ],
    );
  }

  /// تقارير موظف واحد من الأحدث للأقدم (ضمن نطاق التاريخ المختار).
  Widget _employeeReports(List<DailyReport> all) {
    final reports = all
        .where((r) => r.uid == _uid && _passes(r.date))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // الأحدث أولاً

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'كل الموظفين',
              icon: const Icon(Icons.arrow_forward, color: AppColors.cream),
              onPressed: () => setState(() => _uid = null),
            ),
            Expanded(
              child: Text('تقارير: $_selectedName',
                  style: const TextStyle(
                      color: AppColors.cream,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _periodFilter(),
        _dateFilter(),
        const SizedBox(height: 8),
        Text('عدد التقارير: ${reports.length}',
            style: const TextStyle(
                color: AppColors.creamDim, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (reports.isEmpty)
          const EmptyState(
              message: 'لا توجد تقارير في هذه الفترة.', icon: Icons.event_busy)
        else
          ...reports.map(_reportTile),
      ],
    );
  }

  Widget _reportTile(DailyReport r) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.event_note, color: AppColors.oliveBright),
        title: Text(Fmt.date(r.date),
            style: const TextStyle(
                color: AppColors.cream, fontWeight: FontWeight.bold)),
        subtitle: r.projectName.isEmpty
            ? null
            : Text('🔗 ${r.projectName}',
                style: const TextStyle(color: AppColors.creamDim, fontSize: 12)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.content.isEmpty ? 'لا يوجد محتوى.' : r.content,
              style: const TextStyle(color: AppColors.cream, height: 1.6)),
        ],
      ),
    );
  }
}
