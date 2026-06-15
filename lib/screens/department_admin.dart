import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/project_tasks.dart';
import 'design_project_detail.dart';
import 'execution_project_detail.dart';
import 'project_form.dart';

int _rem(Map<String, dynamic> d) {
  final v = d['remainingDays'] ?? d['days'] ?? 0;
  final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
  return n < 0 ? 0 : n;
}

/// شاشة إدارية لقسم (تصميم/تنفيذ): تعرض موظفي القسم وأيامهم المتبقية،
/// والدخول إلى مشاريع كل موظف وإضافة مشروع له (من لوحة التحكم).
class DepartmentAdminScreen extends StatelessWidget {
  final String kind; // 'design' | 'execution'
  const DepartmentAdminScreen({required this.kind, super.key});

  bool get isExec => kind == 'execution';
  String get title => isExec ? 'قسم التنفيذ' : 'قسم التصميم';
  String get keyword => isExec ? 'تنفيذ' : 'تصميم';
  CollectionReference<Map<String, dynamic>> get coll =>
      isExec ? Db.executionProjects : Db.designProjects;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: Db.departments.snapshots(),
        builder: (context, deptSnap) {
          final deptIds = (deptSnap.data?.docs ?? [])
              .where((d) =>
                  (d.data()['name'] ?? '').toString().contains(keyword))
              .map((d) => d.id)
              .toSet();
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: Db.employees.snapshots(),
            builder: (context, empSnap) {
              if (empSnap.hasError) {
                return const MessageView(
                    icon: Icons.cloud_off,
                    title: 'تعذّر تحميل الموظفين',
                    color: AppColors.danger);
              }
              if (!empSnap.hasData || !deptSnap.hasData) {
                return const LoadingView();
              }
              final emps = empSnap.data!.docs
                  .where((e) => deptIds.contains(e.data()['departmentId']))
                  .toList();
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: coll.snapshots(),
                builder: (context, projSnap) {
                  final days = <String, int>{};
                  final counts = <String, int>{};
                  final unassigned =
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                  for (final p in projSnap.data?.docs ?? []) {
                    final ids = assignedIdList(p.data());
                    if (ids.isEmpty) {
                      unassigned.add(p);
                      continue;
                    }
                    // المشروع يُحسب لكل موظف مكلّف به (فريق المشروع).
                    for (final eid in ids) {
                      days[eid] = (days[eid] ?? 0) + _rem(p.data());
                      counts[eid] = (counts[eid] ?? 0) + 1;
                    }
                  }
                  return PagePadding(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader('موظفو $title',
                            intro:
                                'اضغط على موظف لعرض مشاريعه وإضافة مشروع له.'),
                        if (emps.isEmpty)
                          const MessageView(
                            icon: Icons.people_outline,
                            title: 'لا يوجد موظفون في هذا القسم',
                            subtitle:
                                'أضِف الموظفين من قسم «الأقسام والموظفون» في لوحة التحكم.',
                          )
                        else
                          AutoGrid(
                            minTileWidth: 300,
                            gap: 12,
                            children: [
                              for (final e in emps)
                                _empCard(context, e, counts[e.id] ?? 0,
                                    days[e.id] ?? 0),
                            ],
                          ),
                        if (unassigned.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          SectionHeader('مشاريع غير مُسندة',
                              intro:
                                  'مشاريع بلا فريق — افتحها لإسناد الموظفين إليها.'),
                          AutoGrid(
                            minTileWidth: 300,
                            gap: 12,
                            children: [
                              for (final p in unassigned)
                                _unassignedCard(context, p),
                            ],
                          ),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _unassignedCard(
      BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> p) {
    final d = p.data();
    final owner = (d['ownerName'] ?? d['name'] ?? 'مشروع').toString();
    final phone = (d['ownerPhone'] ?? '').toString();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => isExec
            ? ExecutionProjectDetailScreen(
                employee: const EmployeeSession('', 'الإدارة'),
                reference: p.reference,
                canManage: true)
            : DesignProjectDetailScreen(
                employee: const EmployeeSession('', 'الإدارة'),
                reference: p.reference,
                canManage: true),
      )),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cream50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.folder_off_outlined, color: AppColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(owner,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  if (phone.isNotEmpty)
                    Text(phone,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: AppColors.green700),
          ],
        ),
      ),
    );
  }

  Widget _empCard(BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> e, int count, int days) {
    final name = (e.data()['name'] ?? '').toString();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AdminEmployeeProjectsScreen(
          employee: EmployeeSession(e.id, name),
          kind: kind,
        ),
      )),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.cream100,
              child: Text(name.isEmpty ? 'ع' : name.characters.first,
                  style: const TextStyle(
                      color: AppColors.green700,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('$count مشروع · $days يوم متبقٍ',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: AppColors.green700),
          ],
        ),
      ),
    );
  }
}

/// مشاريع موظف معيّن (إدارة): عرض المشاريع + إضافة مشروع + فتح صفحة المشروع.
class AdminEmployeeProjectsScreen extends StatelessWidget {
  final EmployeeSession employee;
  final String kind;
  const AdminEmployeeProjectsScreen(
      {required this.employee, required this.kind, super.key});

  bool get isExec => kind == 'execution';
  CollectionReference<Map<String, dynamic>> get coll =>
      isExec ? Db.executionProjects : Db.designProjects;

  void _addProject(BuildContext context) {
    showAddProjectFlow(context, kind: kind, preset: employee);
  }

  void _openProject(
      BuildContext context, DocumentReference<Map<String, dynamic>> ref) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => isExec
          ? ExecutionProjectDetailScreen(
              employee: employee, reference: ref, canManage: true)
          : DesignProjectDetailScreen(
              employee: employee, reference: ref, canManage: true),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('مشاريع: ${employee.name}')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: coll.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const MessageView(
                icon: Icons.cloud_off,
                title: 'تعذّر تحميل المشاريع',
                color: AppColors.danger);
          }
          if (!snap.hasData) return const LoadingView();
          final docs = snap.data!.docs
              .where((d) => projectAssignedTo(d.data(), employee.id))
              .toList()
            ..sort((a, b) {
              final ta = a.data()['createdAt'];
              final tb = b.data()['createdAt'];
              final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
              final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
              return mb.compareTo(ma);
            });
          final totalDays =
              docs.fold<int>(0, (s, d) => s + _rem(d.data()));

          return PagePadding(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.green800,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(employee.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(
                                '${docs.length} مشروع · $totalDays يوم متبقٍ',
                                style: const TextStyle(
                                    color: AppColors.cream200, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المشاريع',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    ElevatedButton.icon(
                      onPressed: () => _addProject(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إضافة مشروع'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (docs.isEmpty)
                  const MessageView(
                    icon: Icons.folder_open,
                    title: 'لا توجد مشاريع لهذا الموظف',
                    subtitle: 'اضغط «إضافة مشروع» لإسناد مشروع له.',
                  )
                else
                  AutoGrid(
                    minTileWidth: 300,
                    gap: 12,
                    children: [for (final d in docs) _projectCard(context, d)],
                  ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _projectCard(
      BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final status = (d['status'] ?? 'قيد التنفيذ').toString();
    final suspended = status.contains('معلّق') || status.contains('معلق');
    final remaining = _rem(d);
    final done = remaining == 0;
    final tasks = (d['tasks'] as List?) ?? [];
    final pct = taskProgressPercent(tasks);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openProject(context, doc.reference),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: done ? AppColors.cream100 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(d['name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                StatusBadge(status),
              ],
            ),
            if ((d['ownerName'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('صاحب المشروع: ${d['ownerName']}',
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
            if (assignedNamesLabel(d).isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.groups_outlined,
                    size: 13, color: AppColors.green700),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('الفريق: ${assignedNamesLabel(d)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.green700, fontSize: 12)),
                ),
              ]),
            ],
            const SizedBox(height: 10),
            if (tasks.isNotEmpty) ...[
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
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
                suspended
                    ? '⏸️ معلّق — الأيام مجمّدة'
                    : (done ? 'مكتمل' : '$remaining يوم متبقٍ'),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: suspended
                        ? const Color(0xFF9A6700)
                        : AppColors.textSoft)),
          ],
        ),
      ),
    );
  }
}
