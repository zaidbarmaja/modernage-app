import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/design_project.dart';
import '../../models/expense.dart';
import '../../models/work_site.dart';
import '../../services/firestore_service.dart';
import '../../widgets/execution_widgets.dart';
import '../../widgets/project_card.dart';
import '../../widgets/site_card.dart';
import '../../widgets/ui.dart';
import '../attendance/attendance_view.dart';
import '../execution/site_detail_screen.dart';

/// صفحة موظف (للمحاسبة): بصمته + أعماله.
class EmployeeDetailScreen extends StatelessWidget {
  final AppUser employee;
  final AppUser viewer;
  const EmployeeDetailScreen({
    super.key,
    required this.employee,
    required this.viewer,
  });

  bool get _isDesigner => employee.role == UserRole.designEmployee;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(employee.name),
          bottom: const TabBar(
            labelColor: AppColors.cream,
            unselectedLabelColor: AppColors.creamDim,
            indicatorColor: AppColors.oliveBright,
            tabs: [
              Tab(text: 'البصمة', icon: Icon(Icons.fingerprint)),
              Tab(text: 'الأعمال', icon: Icon(Icons.work)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AttendanceView(user: employee, interactive: false),
            _isDesigner
                ? _DesignerWork(employee: employee)
                : _ExecutorWork(employee: employee, viewer: viewer),
          ],
        ),
      ),
    );
  }
}

class _DesignerWork extends StatelessWidget {
  final AppUser employee;
  const _DesignerWork({required this.employee});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<DesignProject>>(
      stream: fs.projectsByDesigner(employee.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final projects = snapshot.data ?? [];
        if (projects.isEmpty) {
          return const EmptyState(
              message: 'لا توجد مشاريع لهذا المصمّم.',
              icon: Icons.architecture);
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: projects.map((p) => ProjectCard(project: p)).toList(),
        );
      },
    );
  }
}

class _ExecutorWork extends StatelessWidget {
  final AppUser employee;
  final AppUser viewer;
  const _ExecutorWork({required this.employee, required this.viewer});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ملخّص السلف والصرفيات لهذا المنفّذ.
        StreamBuilder<List<Expense>>(
          stream: fs.expensesByExecutor(employee.uid),
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            num advances = 0, spending = 0;
            for (final e in items) {
              if (e.type == ExpenseType.advance) {
                advances += e.amount;
              } else {
                spending += e.amount;
              }
            }
            return SectionCard(
              title: 'السلف والصرفيات',
              icon: Icons.payments,
              child: Column(
                children: [
                  InfoRow(
                      label: 'إجمالي السلف',
                      value: Fmt.money(advances),
                      valueColor: AppColors.warning),
                  InfoRow(
                      label: 'إجمالي الصرفيات',
                      value: Fmt.money(spending),
                      valueColor: AppColors.danger),
                  InfoRow(
                      label: 'المجموع',
                      value: Fmt.money(advances + spending)),
                  if (items.isNotEmpty) const Divider(height: 20),
                  ...items.take(20).map((e) => ExpenseTile(expense: e)),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text('المواقع المسندة',
            style: const TextStyle(
                color: AppColors.cream,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        StreamBuilder<List<WorkSite>>(
          stream: fs.sitesByExecutor(employee.uid),
          builder: (context, snapshot) {
            final sites = snapshot.data ?? [];
            if (sites.isEmpty) {
              return const EmptyState(
                  message: 'لا توجد مواقع مسندة لهذا المنفّذ.',
                  icon: Icons.location_city);
            }
            return Column(
              children: sites
                  .map((s) => SiteCard(
                        site: s,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SiteDetailScreen(
                                site: s, user: viewer, interactive: false),
                          ),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
