import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/session.dart';
import '../theme.dart';
import '../utils/time_utils.dart';
import '../widgets/common.dart';
import 'attendance_viewer.dart';
import 'daily_report.dart';
import 'department_admin.dart';
import 'design_screen.dart';
import 'employee_perspective.dart';
import 'execution_screen.dart';
import 'fingerprint_screen.dart';
import 'project_form.dart';

class DashboardScreen extends StatefulWidget {
  /// التنقّل إلى تبويب آخر في الواجهة الرئيسية (التصميم/التنفيذ/…).
  final void Function(int index)? onOpenTab;
  /// فتح بوابة الزبون.
  final VoidCallback? onOpenClient;
  const DashboardScreen({this.onOpenTab, this.onOpenClient, super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _depts = [];
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _emps = [];
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _design = [];
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _exec = [];
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _att = [];
  Set<String> _holidays = {};

  final _subs = <StreamSubscription>[];
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      await Db.seedDefaultDepartments();
    } catch (_) {}
    _listen(Db.departments.orderBy('createdAt'), _depts);
    _listen(Db.employees.orderBy('createdAt'), _emps);
    _listen(Db.designProjects, _design);
    _listen(Db.executionProjects, _exec);
    _listen(Db.attendance, _att);
    _subs.add(Db.holidays.snapshots().listen((s) {
      if (!mounted) return;
      setState(() => _holidays = s.docs.map((d) => d.id).toSet());
    }));
    setState(() => _ready = true);
  }

  void _listen(Query<Map<String, dynamic>> q,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> target) {
    _subs.add(q.snapshots().listen((s) {
      if (!mounted) return;
      setState(() {
        target
          ..clear()
          ..addAll(s.docs);
      });
    }));
  }

  int _remaining(Map<String, dynamic> d) {
    final v = d['remainingDays'] ?? d['days'] ?? 0;
    final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
    return n < 0 ? 0 : n;
  }

  int _expenses(Map<String, dynamic> d) {
    final e = d['expenses'];
    if (e is List) {
      return e.fold<int>(0, (x, item) {
        final a = (item is Map) ? item['amount'] : 0;
        return x + ((a is num) ? a.toInt() : 0);
      });
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const LoadingView(text: 'جارٍ التحميل…');
    }
    final allProjects = [..._design, ..._exec];
    final openNames = _att
        .where((a) => a.data()['checkOut'] == null)
        .map((a) => (a.data()['name'] ?? '').toString().trim())
        .toSet();

    final designRemaining =
        _design.fold<int>(0, (s, p) => s + _remaining(p.data()));
    final execRemaining =
        _exec.fold<int>(0, (s, p) => s + _remaining(p.data()));
    final totalExpenses =
        _exec.fold<int>(0, (s, p) => s + _expenses(p.data()));

    final kpis = <Widget>[
      KpiCard('عدد الموظفين', '${_emps.length}',
          icon: Icons.people_alt_outlined),
      KpiCard('عدد الأقسام', '${_depts.length}',
          icon: Icons.apartment_outlined),
      KpiCard('التصاميم الموجودة', '${_design.length}',
          icon: Icons.brush_outlined),
      KpiCard('مشاريع التنفيذ', '${_exec.length}',
          icon: Icons.construction_outlined),
      KpiCard('أيام التصميم المتبقية', '$designRemaining يوم',
          icon: Icons.schedule_outlined),
      KpiCard('أيام التنفيذ المتبقية', '$execRemaining يوم',
          icon: Icons.timelapse_outlined),
      KpiCard('إجمالي المصروفات', '${arNumber(totalExpenses)} د.ع',
          icon: Icons.payments_outlined),
      KpiCard('داخل الآن', '${openNames.length}',
          icon: Icons.login_outlined,
          accent: openNames.isEmpty ? AppColors.muted : AppColors.green600),
    ];

    return PagePadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageTitle(),
          const SizedBox(height: 20),

          // ===== إضافة مشروع جديد (المدخل الرئيسي) =====
          _addProjectHero(),
          const SizedBox(height: 28),

          // ===== ١) الصفحات =====
          const SectionHeader('الصفحات',
              intro: 'انتقل بسرعة إلى أقسام النظام.'),
          _navSection(),
          const SizedBox(height: 28),

          // ===== الصفحات من منظور المستخدم =====
          const SectionHeader('الصفحات من منظور المستخدم',
              intro:
                  'جرّب التطبيق كما يراه الزبون أو الموظف من خلال هذه المداخل.'),
          _perspectiveSection(),
          const SizedBox(height: 28),

          // ===== ٢) الأقسام والموظفون =====
          const SectionHeader('الأقسام والموظفون',
              intro:
                  'أضِف موظفًا أو مشروعًا، وادخل إلى «صفحته» أو «البصمة».'),
          _departmentsGrid(),
          const SizedBox(height: 28),

          // ===== ٣) موقع البصمة وتسجيل الحضور =====
          const SectionHeader('موقع البصمة وتسجيل الحضور',
              intro:
                  'حدّد موقع بصمة لكل قسم، مع نطاقه ومواعيد وأيام دوامه.'),
          _AttendanceLocationsManager(departments: _depts),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      const AttendanceViewerScreen(canManage: true))),
              icon: const Icon(Icons.fingerprint, size: 18),
              label: const Text('مشاهدة وإدارة بصمات الموظفين'),
            ),
          ),
          const SizedBox(height: 28),

          // ===== التقارير اليومية للموظفين =====
          const SectionHeader('التقارير اليومية للموظفين',
              intro:
                  'اطّلع على ما أنجزه كل موظف في يومه، مع إمكانية اختيار أيام سابقة.'),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const DailyReportsScreen())),
              icon: const Icon(Icons.assignment_outlined, size: 18),
              label: const Text('عرض تقارير الموظفين اليومية'),
            ),
          ),
          const SizedBox(height: 28),

          // ===== ٤) نظرة عامة (إحصائيات) =====
          const SectionHeader('نظرة عامة',
              intro: 'أرقام النظام في لمحة واحدة.'),
          AutoGrid(minTileWidth: 165, gap: 12, children: kpis),
          const SizedBox(height: 28),

          // ===== ساعات عمل الموظفين =====
          const SectionHeader('ساعات عمل الموظفين',
              intro: 'إجمالي ساعات العمل والساعات الإضافية لكل موظف.'),
          _employeeHoursSection(),
          const SizedBox(height: 28),

          // ===== ٥) تفاصيل إضافية =====
          const SectionHeader('إدارة العطل الرسمية',
              intro:
                  'حدّد أي يوم كعطلة رسمية: لن يُحتسب ضمن ساعات الموظفين، ولن يتمكّن أي موظف من تسجيل الدخول فيه.'),
          _holidaysBlock(),
          const SizedBox(height: 28),
          const SectionHeader('الأقسام: الموظفون والمشاريع',
              intro: 'عدد الموظفين والمشاريع والأيام المتبقية لكل قسم.'),
          _deptStatsGrid(allProjects),
          const SizedBox(height: 28),
          const SectionHeader('أحدث النشاطات'),
          _activityList(allProjects),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ===== رأس الصفحة =====
  Widget _pageTitle() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppColors.green800, AppColors.green600],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
                color: Colors.white24, shape: BoxShape.circle),
            child: const Icon(Icons.dashboard_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('لوحة التحكم',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('عصر الحداثة — إدارة المهام والتقارير',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.cream200, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== المدخل الرئيسي: إضافة مشروع جديد =====
  Widget _addProjectHero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.green600.withValues(alpha: 0.4)),
        gradient: const LinearGradient(
          colors: [AppColors.cream100, Colors.white],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.green600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_box_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إضافة مشروع جديد',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text(
                        'اختر النوع، أدخل تفاصيل المشروع، وكلّف الموظفين المسؤولين عنه.',
                        style:
                            TextStyle(color: AppColors.textSoft, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      showAddProjectFlow(context, kind: 'design'),
                  icon: const Icon(Icons.brush_outlined, size: 18),
                  label: const Text('مشروع تصميم'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      showAddProjectFlow(context, kind: 'execution'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green700),
                  icon: const Icon(Icons.construction_outlined, size: 18),
                  label: const Text('مشروع تنفيذ'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== ساعات عمل الموظفين =====
  Widget _employeeHoursSection() {
    if (_emps.isEmpty) {
      return const Text('لا يوجد موظفون بعد.',
          style: TextStyle(color: AppColors.muted));
    }
    return AutoGrid(
      minTileWidth: 240,
      gap: 12,
      children: [
        for (final e in _emps)
          Builder(builder: (_) {
            final name = (e.data()['name'] ?? '').toString();
            final h = employeeHours(e.id, name);
            return Container(
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
                        radius: 16,
                        backgroundColor: AppColors.cream100,
                        child: Text(
                            name.isEmpty ? 'ع' : name.characters.first,
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
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _hoursPill('العمل',
                            WorkTime.minutesToText(h.worked),
                            AppColors.green100, AppColors.green800),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _hoursPill('الإضافي',
                            WorkTime.minutesToText(h.overtime),
                            AppColors.cream100, AppColors.green700),
                      ),
                    ],
                  ),
                  if (h.late > 0) ...[
                    const SizedBox(height: 8),
                    _hoursPill('التأخير', WorkTime.minutesToText(h.late),
                        AppColors.dangerSoft, AppColors.danger),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _hoursPill(String label, String value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: fg, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  void _openDepartment(String kind) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DepartmentAdminScreen(kind: kind),
    ));
  }

  // ===== قسم الصفحات (تنقّل) =====
  Widget _navSection() {
    return AutoGrid(
      minTileWidth: 165,
      gap: 12,
      children: [
        _navCard('قسم التصميم', 'موظفو ومشاريع التصميم', Icons.brush_outlined,
            AppColors.green600, () => _openDepartment('design')),
        _navCard('قسم التنفيذ', 'موظفو ومشاريع التنفيذ',
            Icons.construction_outlined, AppColors.green700,
            () => _openDepartment('execution')),
        _navCard('التقارير', 'تقارير الأداء', Icons.bar_chart_outlined,
            AppColors.green700, () => widget.onOpenTab?.call(3)),
        _navCard('البصمات والتأخير', 'حضور الموظفين وتأخيرهم وتعديلها',
            Icons.fingerprint, AppColors.green600,
            () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    const AttendanceViewerScreen(canManage: true)))),
      ],
    );
  }

  // ===== قسم: منظور المستخدم (الزبون / الموظف) =====
  Widget _perspectiveSection() {
    return AutoGrid(
      minTileWidth: 240,
      gap: 12,
      children: [
        _navCard(
            'منظور الزبون',
            'ادخل التطبيق كأنك زبون يتصفّح ويتسوّق',
            Icons.storefront_outlined,
            AppColors.green800,
            () => widget.onOpenClient?.call()),
        _navCard(
            'منظور الموظف',
            'ادخل عبر كارنيه الموظف لرؤية صفحاته',
            Icons.badge_outlined,
            AppColors.green600,
            () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const EmployeePerspectiveScreen()))),
      ],
    );
  }

  Widget _navCard(String title, String sub, IconData icon, Color color,
      VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [color, AppColors.green900],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                    color: Colors.white24, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 12),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.cream200, fontSize: 11)),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Text('دخول',
                      style: TextStyle(color: AppColors.cream100, fontSize: 12)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_back, color: Colors.white, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== الأقسام + الموظفون =====
  Widget _departmentsGrid() {
    final ordered = _depts.toList()
      ..sort((a, b) {
        final oa = Db.deptOrder[a.data()['name']] ?? 50;
        final ob = Db.deptOrder[b.data()['name']] ?? 50;
        return oa.compareTo(ob);
      });
    return AutoGrid(
      minTileWidth: 320,
      gap: 14,
      children: [for (final d in ordered) _DeptCard(this, d)],
    );
  }

  ({int late, int overtime, int worked}) employeeHours(
      String empId, String empName) {
    int late = 0, overtime = 0, worked = 0;
    for (final a in _att) {
      final d = a.data();
      final match = d['employeeId'] != null
          ? d['employeeId'] == empId
          : (d['name'] ?? '').toString().trim() == empName.trim();
      if (!match || d['checkOut'] == null) continue;
      if (_holidays.contains(WorkTime.attendanceDateKey(d))) continue;
      final s = WorkTime.stats(d);
      late += s.late;
      overtime += s.overtime;
      worked += s.worked;
    }
    return (late: late, overtime: overtime, worked: worked);
  }

  // ===== العطل =====
  Widget _holidaysBlock() {
    final days = _holidays.toList()..sort((a, b) => b.compareTo(a));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _pickHoliday,
              icon: const Icon(Icons.event, size: 18),
              label: const Text('تحديد يوم كعطلة'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (days.isEmpty)
          const Text('لا توجد أيام عطلة محدّدة.',
              style: TextStyle(color: AppColors.muted))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in days)
                Chip(
                  label: Text('📅 $d'),
                  onDeleted: () => Db.removeHoliday(d),
                  backgroundColor: AppColors.cream100,
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _pickHoliday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      await Db.addHoliday(WorkTime.dateKey(picked));
    }
  }

  // ===== المشاريع حسب القسم =====
  Widget _deptStatsGrid(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> allProjects) {
    final empDept = {for (final e in _emps) e.id: e.data()['departmentId']};
    final stats = <String, ({int projects, int remaining})>{};
    for (final p in allProjects) {
      final dId = empDept[p.data()['employeeId']];
      if (dId == null) continue;
      final cur = stats[dId] ?? (projects: 0, remaining: 0);
      stats[dId] = (
        projects: cur.projects + 1,
        remaining: cur.remaining + _remaining(p.data())
      );
    }
    if (_depts.isEmpty) {
      return const Text('لا توجد أقسام بعد.',
          style: TextStyle(color: AppColors.muted));
    }
    return AutoGrid(
      minTileWidth: 200,
      gap: 12,
      children: [
        for (final d in _depts)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Builder(builder: (_) {
              final empCount = _emps
                  .where((e) => e.data()['departmentId'] == d.id)
                  .length;
              final st = stats[d.id] ?? (projects: 0, remaining: 0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.data()['name'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.green900)),
                  const SizedBox(height: 6),
                  Text('${st.projects}',
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w800)),
                  Text('$empCount موظف · ${st.remaining} يوم متبقٍ',
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              );
            }),
          ),
      ],
    );
  }

  // ===== النشاطات =====
  Widget _activityList(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> allProjects) {
    final items = <({int ms, String icon, String text})>[];
    for (final p in allProjects) {
      final d = p.data();
      final isExec = _exec.contains(p);
      final t = d['createdAt'];
      items.add((
        ms: t is Timestamp ? t.millisecondsSinceEpoch : 0,
        icon: isExec ? '🏗️' : '🎨',
        text:
            '${d['employeeName'] ?? '—'} — مشروع «${d['name'] ?? ''}» (${isExec ? 'تنفيذ' : 'تصميم'}) · ${_remaining(d)} يوم متبقٍ',
      ));
    }
    for (final a in _att) {
      final d = a.data();
      final base = d['checkOut'] ?? d['checkIn'];
      final ms = DateTime.tryParse('$base')?.millisecondsSinceEpoch ?? 0;
      items.add((
        ms: ms,
        icon: d['checkOut'] != null ? '🚪' : '✅',
        text:
            '${d['name'] ?? ''} — ${d['checkOut'] != null ? 'سجّل الانصراف' : 'سجّل الحضور'}',
      ));
    }
    items.sort((a, b) => b.ms.compareTo(a.ms));
    final top = items.take(12).toList();
    if (top.isEmpty) {
      return const Text('لا يوجد نشاط بعد.',
          style: TextStyle(color: AppColors.muted));
    }
    return Column(
      children: [
        for (final i in top)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Text(i.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(child: Text(i.text)),
              ],
            ),
          ),
      ],
    );
  }

  // ===== فتح صفحة موظف نيابةً عنه =====
  void openEmployeeAs(String id, String name, String deptName) async {
    final isExec = deptName.contains('تنفيذ');
    final key = isExec ? Session.executionKey : Session.designKey;
    await Session.set(key, EmployeeSession(id, name));
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text('صفحة: $name')),
        body: isExec
            ? const ExecutionScreen(canManage: true)
            : const DesignScreen(canManage: true),
      ),
    ));
  }

  /// إضافة مشروع لموظف من لوحة التحكم (الإنشاء صلاحية المدير حصرًا).
  /// يُفتح النموذج الموحّد مع تكليف الموظف مسبقًا مع إمكانية إضافة زملاء له.
  void addProjectFor(String id, String name, String deptName) {
    final isExec = deptName.contains('تنفيذ');
    showAddProjectFlow(
      context,
      kind: isExec ? 'execution' : 'design',
      preset: EmployeeSession(id, name),
    );
  }

  void openFingerprintAs(String id, String name) async {
    await Session.set(Session.fingerprintKey, EmployeeSession(id, name));
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text('بصمة: $name')),
        body: const FingerprintScreen(canManage: true),
      ),
    ));
  }
}

class _DeptCard extends StatefulWidget {
  final _DashboardScreenState parent;
  final QueryDocumentSnapshot<Map<String, dynamic>> dept;
  const _DeptCard(this.parent, this.dept);
  @override
  State<_DeptCard> createState() => _DeptCardState();
}

class _DeptCardState extends State<_DeptCard> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  IconData _deptIcon(String name) {
    if (name.contains('تصميم')) return Icons.brush_outlined;
    if (name.contains('تنفيذ')) return Icons.construction_outlined;
    if (name.contains('محاسب')) return Icons.calculate_outlined;
    return Icons.apartment_outlined;
  }

  Future<void> _add() async {
    final n = _name.text.trim();
    final c = _code.text.trim();
    if (n.isEmpty || c.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('أدخل اسم الموظف والرمز السري')));
      return;
    }
    await Db.addEmployee(widget.dept.id, n, c);
    _name.clear();
    _code.clear();
    if (mounted) setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.parent;
    final deptName = (widget.dept.data()['name'] ?? '').toString();
    final emps =
        p._emps.where((e) => e.data()['departmentId'] == widget.dept.id).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.cream100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_deptIcon(deptName),
                    size: 20, color: AppColors.green700),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(deptName,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              Text('${emps.length} موظف',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          if (emps.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('لا يوجد موظفون في هذا القسم بعد',
                  style: TextStyle(color: AppColors.muted)),
            )
          else
            for (final e in emps) _employeeRow(p, e, deptName),
          const SizedBox(height: 4),
          if (_adding) ...[
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(hintText: 'اسم الموظف'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _code,
                    decoration: const InputDecoration(hintText: 'الرمز السري'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(onPressed: _add, child: const Text('حفظ')),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => setState(() => _adding = false),
                  child: const Text('إلغاء'),
                ),
              ],
            ),
          ] else
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _adding = true),
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('إضافة موظف'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _employeeRow(_DashboardScreenState p,
      QueryDocumentSnapshot<Map<String, dynamic>> e, String deptName) {
    final data = e.data();
    final name = (data['name'] ?? '').toString();
    final h = p.employeeHours(e.id, name);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cream50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('الرمز: ${data['code'] ?? ''}',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'حذف',
                onPressed: () async {
                  final ok = await _confirm(context, 'حذف الموظف «$name»؟');
                  if (ok) await Db.deleteEmployee(e.id);
                },
                icon: const Icon(Icons.close, color: AppColors.danger, size: 18),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip('عمل: ${WorkTime.minutesToText(h.worked)}'),
              _chip('إضافي: ${WorkTime.minutesToText(h.overtime)}',
                  color: AppColors.green100),
              _chip('تأخير: ${WorkTime.minutesToText(h.late)}',
                  color: AppColors.dangerSoft),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (deptName.contains('تصميم') || deptName.contains('تنفيذ'))
                ElevatedButton.icon(
                  onPressed: () => p.addProjectFor(e.id, name, deptName),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('إضافة مشروع'),
                ),
              OutlinedButton(
                onPressed: () => p.openEmployeeAs(e.id, name, deptName),
                child: const Text('صفحته'),
              ),
              OutlinedButton(
                onPressed: () => p.openFingerprintAs(e.id, name),
                child: const Text('البصمة'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, {Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color ?? AppColors.cream200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11)),
      );
}

Future<bool> _confirm(BuildContext context, String message) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء')),
        TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف')),
      ],
    ),
  );
  return res ?? false;
}

/// قسم لوحة التحكم لتحديد موقع البصمة المسموح (مركز جغرافي + نطاق بالأمتار).
/// مدير مواقع البصمة في لوحة التحكم: عرض/إضافة/تعديل/حذف مواقع لكل قسم.
class _AttendanceLocationsManager extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> departments;
  const _AttendanceLocationsManager({required this.departments});

  void _openForm(BuildContext context, AttendanceLocation? existing) {
    showDialog(
      context: context,
      builder: (_) =>
          _LocationFormDialog(departments: departments, existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deptNameOf = {
      for (final d in departments) d.id: (d.data()['name'] ?? '').toString()
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: Db.attendanceLocations.snapshots(),
          builder: (context, snap) {
            final locs = (snap.data?.docs ?? [])
                .map((d) => AttendanceLocation.fromDoc(d.id, d.data()))
                .whereType<AttendanceLocation>()
                .toList();
            if (snap.hasData && locs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_off, color: AppColors.muted),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          'لا توجد مواقع بصمة بعد. أضِف موقعًا لكل قسم بالضغط على «إضافة موقع بصمة».',
                          style: TextStyle(color: AppColors.textSoft)),
                    ),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final l in locs)
                  _locationCard(context, l, deptNameOf[l.departmentId] ?? '—'),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: () => _openForm(context, null),
            icon: const Icon(Icons.add_location_alt, size: 18),
            label: const Text('إضافة موقع بصمة'),
          ),
        ),
      ],
    );
  }

  Widget _locationCard(
      BuildContext context, AttendanceLocation l, String deptName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.location_on, color: AppColors.green700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.name.isEmpty ? 'موقع بصمة' : l.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              IconButton(
                tooltip: 'تعديل',
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () => _openForm(context, l),
              ),
              IconButton(
                tooltip: 'حذف',
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.danger),
                onPressed: () async {
                  final ok =
                      await _confirm(context, 'حذف موقع «${l.name}»؟');
                  if (ok) await Db.deleteAttendanceLocation(l.id);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          _kv('القسم', deptName),
          _kv('النطاق', '${l.radius} متر'),
          _kv('الدوام',
              '${ArDate.clockLabel(l.workStart)} — ${ArDate.clockLabel(l.workEnd)}'),
          _kv('الأيام', arWeekdaysLabel(l.workDays)),
          _kv('الإحداثيات',
              '${l.lat.toStringAsFixed(5)}, ${l.lng.toStringAsFixed(5)}'),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: AppColors.textSoft, fontSize: 13),
            children: [
              TextSpan(
                  text: '$k: ',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: v),
            ],
          ),
        ),
      );
}

/// نموذج إضافة/تعديل موقع بصمة.
class _LocationFormDialog extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> departments;
  final AttendanceLocation? existing;
  const _LocationFormDialog({required this.departments, this.existing});
  @override
  State<_LocationFormDialog> createState() => _LocationFormDialogState();
}

class _LocationFormDialogState extends State<_LocationFormDialog> {
  static const _radiusOptions = [100, 250, 500, 1000, 2000, 5000];
  late final TextEditingController _name;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  // أيام الأسبوع بالترتيب العربي مع ترقيم DateTime.weekday.
  static const _weekDays = <({String label, int wd})>[
    (label: 'الأحد', wd: 7),
    (label: 'الإثنين', wd: 1),
    (label: 'الثلاثاء', wd: 2),
    (label: 'الأربعاء', wd: 3),
    (label: 'الخميس', wd: 4),
    (label: 'الجمعة', wd: 5),
    (label: 'السبت', wd: 6),
  ];

  String? _deptId;
  int _radius = 100;
  int _workStart = 8 * 60;
  int _workEnd = 16 * 60;
  final Set<int> _workDays = {};
  bool _locating = false;
  bool _busy = false;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _lat = TextEditingController(text: e != null ? '${e.lat}' : '');
    _lng = TextEditingController(text: e != null ? '${e.lng}' : '');
    _radius = e?.radius ?? 100;
    _workStart = e?.workStart ?? 8 * 60;
    _workEnd = e?.workEnd ?? 16 * 60;
    _workDays.addAll(e?.workDays ?? AttendanceLocation.defaultWorkDays);
    final deptIds = widget.departments.map((d) => d.id).toSet();
    if (e != null && deptIds.contains(e.departmentId)) {
      _deptId = e.departmentId;
    } else if (widget.departments.isNotEmpty) {
      _deptId = widget.departments.first.id;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _useCurrent() async {
    setState(() => _locating = true);
    try {
      final loc = await LocationService.getCurrentLocation();
      _lat.text = loc.lat.toStringAsFixed(6);
      _lng.text = loc.lng.toStringAsFixed(6);
      if (_name.text.trim().isEmpty && loc.address.isNotEmpty) {
        _name.text = loc.address;
      }
      if (mounted) setState(() {});
    } on LocationException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('تعذّر تحديد الموقع. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickTime(bool start) async {
    final cur = start ? _workStart : _workEnd;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (cur ~/ 60) % 24, minute: cur % 60),
    );
    if (t != null) {
      setState(() {
        if (start) {
          _workStart = t.hour * 60 + t.minute;
        } else {
          _workEnd = t.hour * 60 + t.minute;
        }
      });
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (name.isEmpty || _deptId == null || lat == null || lng == null) {
      _toast('أدخل الاسم والقسم والإحداثيات (استخدم موقعك الحالي أو اكتبها).');
      return;
    }
    if (_workDays.isEmpty) {
      _toast('اختر يوم دوام واحدًا على الأقل.');
      return;
    }
    final days = _workDays.toList()..sort();
    setState(() => _busy = true);
    try {
      if (isEdit) {
        await Db.updateAttendanceLocation(
          widget.existing!.id,
          name: name,
          lat: lat,
          lng: lng,
          radius: _radius,
          departmentId: _deptId!,
          workStart: _workStart,
          workEnd: _workEnd,
          workDays: days,
        );
      } else {
        await Db.addAttendanceLocation(
          name: name,
          lat: lat,
          lng: lng,
          radius: _radius,
          departmentId: _deptId!,
          workStart: _workStart,
          workEnd: _workEnd,
          workDays: days,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        _toast('تعذّر الحفظ. حاول مجددًا.');
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(isEdit ? 'تعديل موقع البصمة' : 'إضافة موقع بصمة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم الموقع'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _deptId,
                decoration: const InputDecoration(labelText: 'القسم'),
                items: [
                  for (final d in widget.departments)
                    DropdownMenuItem(
                      value: d.id,
                      child: Text((d.data()['name'] ?? '').toString()),
                    ),
                ],
                onChanged: (v) => setState(() => _deptId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _lat,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      decoration: const InputDecoration(labelText: 'خط العرض'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _lng,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      decoration: const InputDecoration(labelText: 'خط الطول'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _locating ? null : _useCurrent,
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location, size: 18),
                  label: const Text('استخدم موقعي الحالي'),
                ),
              ),
              const SizedBox(height: 12),
              const Text('النطاق المسموح (متر)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in _radiusOptions)
                    ChoiceChip(
                      label: Text('$r م'),
                      selected: _radius == r,
                      onSelected: (_) => setState(() => _radius = r),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('مواعيد الدوام',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(true),
                      child: Text('من: ${ArDate.clockLabel(_workStart)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(false),
                      child: Text('إلى: ${ArDate.clockLabel(_workEnd)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('أيام الدوام',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in _weekDays)
                    FilterChip(
                      label: Text(d.label),
                      selected: _workDays.contains(d.wd),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _workDays.add(d.wd);
                        } else {
                          _workDays.remove(d.wd);
                        }
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: _busy ? null : _save,
            child: Text(isEdit ? 'حفظ' : 'إضافة'),
          ),
        ],
      ),
    );
  }
}
