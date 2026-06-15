import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../theme.dart';
import '../utils/time_utils.dart';
import '../widgets/common.dart';
import '../widgets/project_tasks.dart';
import 'attendance_viewer.dart';
import 'daily_report.dart';
import 'project_form.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
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
    _listen(Db.employees, _emps);
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

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  int _remaining(Map<String, dynamic> d) {
    final v = d['remainingDays'] ?? d['days'] ?? 0;
    final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
    return n < 0 ? 0 : n;
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const LoadingView(text: 'جارٍ تحميل التقارير…');
    final allProjects = [..._design, ..._exec];

    // ===== أداء الموظفين =====
    final perf = <_EmpPerf>[];
    for (final e in _emps) {
      final id = e.id;
      final name = (e.data()['name'] ?? '').toString();
      var totalTasks = 0, doneTasks = 0, doneProjects = 0, remaining = 0,
          projects = 0;
      for (final p in allProjects) {
        if (!projectAssignedTo(p.data(), id)) continue;
        projects++;
        final tasks = (p.data()['tasks'] as List?) ?? const [];
        totalTasks += tasks.length;
        doneTasks += tasks.where((t) => t is Map && t['done'] == true).length;
        final st = (p.data()['status'] ?? '').toString();
        final rem = _remaining(p.data());
        remaining += rem;
        if (st.contains('منجز') || st.contains('مكتمل') || rem == 0) {
          doneProjects++;
        }
      }
      if (projects == 0) continue;
      // تأخير الموظف الإجمالي.
      var late = 0;
      for (final a in _att) {
        final d = a.data();
        final match = d['employeeId'] == id ||
            (d['name'] ?? '').toString().trim() == name.trim();
        if (!match || d['checkOut'] == null) continue;
        if (_holidays.contains(WorkTime.attendanceDateKey(d))) continue;
        late += WorkTime.stats(d).late;
      }
      final pct =
          totalTasks == 0 ? 0 : ((doneTasks / totalTasks) * 100).round();
      perf.add(_EmpPerf(
        name: name,
        projects: projects,
        doneProjects: doneProjects,
        progress: pct,
        remaining: remaining,
        lateMinutes: late,
      ));
    }
    // الأسرع إنجازًا: نسبة إنجاز أعلى ثم أيام متبقية أقل.
    perf.sort((a, b) {
      final c = b.progress.compareTo(a.progress);
      if (c != 0) return c;
      return a.remaining.compareTo(b.remaining);
    });

    return PagePadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('التقارير والأداء',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('تقارير الموظفين اليومية، نسب إنجاز المشاريع، والأداء.',
              style: TextStyle(color: AppColors.textSoft)),
          const SizedBox(height: 18),

          // ===== مداخل سريعة =====
          AutoGrid(
            minTileWidth: 240,
            gap: 12,
            children: [
              _entryCard('التقارير اليومية للموظفين', 'ماذا أنجز كل موظف اليوم',
                  Icons.assignment_outlined, AppColors.green600, () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const DailyReportsScreen()));
              }),
              _entryCard('البصمات والتأخير', 'الحضور والانصراف وتعديلها',
                  Icons.fingerprint, AppColors.green700, () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        const AttendanceViewerScreen(canManage: true)));
              }),
            ],
          ),
          const SizedBox(height: 26),

          // ===== أداء الموظفين (الأسرع إنجازًا) =====
          const SectionHeader('أداء الموظفين',
              intro: 'مرتّبون حسب سرعة الإنجاز (نسبة المهام المنجزة).'),
          if (perf.isEmpty)
            const MessageView(
              icon: Icons.people_outline,
              title: 'لا يوجد موظفون لديهم مشاريع بعد',
            )
          else
            Column(children: [for (final p in perf) _perfRow(p)]),
          const SizedBox(height: 26),

          // ===== نسبة إنجاز المشاريع =====
          const SectionHeader('نسبة إنجاز المشاريع',
              intro: 'تقدّم كل مشروع حسب المهام المنجزة.'),
          if (allProjects.isEmpty)
            const MessageView(
                icon: Icons.folder_open, title: 'لا توجد مشاريع بعد')
          else
            Column(children: [
              for (final p in allProjects) _projectRow(p.data(), _exec.contains(p)),
            ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _entryCard(String title, String sub, IconData icon, Color color,
      VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color, AppColors.green900],
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
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: const TextStyle(
                            color: AppColors.cream200, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _perfRow(_EmpPerf p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
                radius: 18,
                backgroundColor: AppColors.cream100,
                child: Text(p.name.isEmpty ? 'ع' : p.name.characters.first,
                    style: const TextStyle(
                        color: AppColors.green700, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(p.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              Text('${p.progress}٪',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.green700)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: p.progress / 100,
              minHeight: 8,
              backgroundColor: AppColors.cream200,
              valueColor: const AlwaysStoppedAnimation(AppColors.green600),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip('${p.projects} مشروع'),
              _chip('${p.doneProjects} منجز', color: AppColors.green100),
              _chip('${p.remaining} يوم متبقٍ'),
              if (p.lateMinutes > 0)
                _chip('تأخير: ${WorkTime.minutesToText(p.lateMinutes)}',
                    color: AppColors.dangerSoft),
            ],
          ),
        ],
      ),
    );
  }

  Widget _projectRow(Map<String, dynamic> d, bool isExec) {
    final pct = taskProgressPercent((d['tasks'] as List?) ?? const []);
    final status = (d['status'] ?? 'قيد التنفيذ').toString();
    final owner = (d['ownerName'] ?? d['name'] ?? 'مشروع').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              Text(isExec ? '🏗️' : '🎨', style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(owner,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              StatusBadge(status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 8,
                    backgroundColor: AppColors.cream200,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.green600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('$pct٪',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Text('${_remaining(d)} يوم',
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ],
      ),
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
}

class _EmpPerf {
  final String name;
  final int projects;
  final int doneProjects;
  final int progress;
  final int remaining;
  final int lateMinutes;
  _EmpPerf({
    required this.name,
    required this.projects,
    required this.doneProjects,
    required this.progress,
    required this.remaining,
    required this.lateMinutes,
  });
}
