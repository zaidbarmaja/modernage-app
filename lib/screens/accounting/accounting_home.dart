import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/design_project.dart';
import '../../models/work_site.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_actions.dart';
import '../../widgets/project_card.dart';
import '../../widgets/site_card.dart';
import '../../widgets/ui.dart';
import '../customer/customer_overview.dart';
import '../execution/site_detail_screen.dart';
import 'employee_detail_screen.dart';

/// لوحة المحاسبة: التصميم + التنفيذ + الموظفون (مع البصمة) + ميزانية الزبائن.
class AccountingHome extends StatefulWidget {
  final AppUser user;
  const AccountingHome({super.key, required this.user});

  @override
  State<AccountingHome> createState() => _AccountingHomeState();
}

class _AccountingHomeState extends State<AccountingHome> {
  int _index = 0;
  static const _titles = ['التصميم', 'التنفيذ', 'الموظفون', 'الزبائن'];

  @override
  Widget build(BuildContext context) {
    // بناء كسول: يُبنى التبويب النشط فقط (لا تبقى مستمعات Firestore لكل التبويبات
    // نشطة معًا) — يقلّل قراءات قاعدة البيانات وتكلفتها.
    final body = switch (_index) {
      0 => const _DesignAccountingTab(),
      1 => _ExecutionAccountingTab(viewer: widget.user),
      2 => _EmployeesTab(viewer: widget.user),
      _ => _CustomersTab(viewer: widget.user),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text('المحاسبة • ${_titles[_index]}'),
        actions: const [LogoutAction()],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.olive,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.architecture), label: 'التصميم'),
          NavigationDestination(
              icon: Icon(Icons.engineering), label: 'التنفيذ'),
          NavigationDestination(icon: Icon(Icons.people), label: 'الموظفون'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet), label: 'الزبائن'),
        ],
      ),
    );
  }
}

/// تبويب التصميم: ملخّص مالي + قائمة المشاريع.
class _DesignAccountingTab extends StatelessWidget {
  const _DesignAccountingTab();

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<DesignProject>>(
      stream: fs.allProjects(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final projects = snapshot.data ?? [];
        num total = 0, paid = 0;
        for (final p in projects) {
          total += p.totalAmount;
          paid += p.paidAmount;
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            SectionCard(
              title: 'ملخّص التصميم',
              icon: Icons.insights,
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.9,
                children: [
                  StatTile(
                      value: '${projects.length}',
                      label: 'عدد المشاريع',
                      icon: Icons.folder),
                  StatTile(
                      value: Fmt.money(paid),
                      label: 'المحصّل',
                      icon: Icons.price_check,
                      color: AppColors.success),
                  StatTile(
                      value: Fmt.money(total - paid),
                      label: 'المتبقي',
                      icon: Icons.pending_actions,
                      color: AppColors.warning),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (projects.isEmpty)
              const EmptyState(
                  message: 'لا توجد مشاريع تصميم.',
                  icon: Icons.architecture)
            else
              ...projects.map((p) => ProjectCard(project: p, showDesigner: true)),
          ],
        );
      },
    );
  }
}

/// تبويب التنفيذ: كل المواقع، الدخول لتفاصيل كل موقع.
class _ExecutionAccountingTab extends StatelessWidget {
  final AppUser viewer;
  const _ExecutionAccountingTab({required this.viewer});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<WorkSite>>(
      stream: fs.allSites(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final sites = snapshot.data ?? [];
        if (sites.isEmpty) {
          return const EmptyState(
              message: 'لا توجد مواقع تنفيذ.', icon: Icons.location_city);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: sites.length,
          itemBuilder: (context, i) => SiteCard(
            site: sites[i],
            showExecutor: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SiteDetailScreen(
                    site: sites[i], user: viewer, interactive: false),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// تبويب الموظفين: قائمة الموظفين والدخول لصفحة كل موظف (مع بصمته).
class _EmployeesTab extends StatelessWidget {
  final AppUser viewer;
  const _EmployeesTab({required this.viewer});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<AppUser>>(
      stream: fs.employeesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final employees = snapshot.data ?? [];
        if (employees.isEmpty) {
          return const EmptyState(
              message: 'لا يوجد موظفون مسجّلون.', icon: Icons.people_outline);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: employees.length,
          itemBuilder: (context, i) {
            final e = employees[i];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.oliveDark,
                  child: Icon(e.role.icon, color: AppColors.cream),
                ),
                title: Text(e.name,
                    style: const TextStyle(
                        color: AppColors.cream,
                        fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${e.role.labelAr}'
                  '${e.department != Department.none ? ' • ${e.department.labelAr}' : ''}',
                  style: const TextStyle(color: AppColors.creamDim),
                ),
                trailing:
                    const Icon(Icons.chevron_left, color: AppColors.creamDim),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EmployeeDetailScreen(employee: e, viewer: viewer),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// تبويب الزبائن: قائمة الزبائن وميزانية كل زبون.
class _CustomersTab extends StatelessWidget {
  final AppUser viewer;
  const _CustomersTab({required this.viewer});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<AppUser>>(
      stream: fs.usersByRole(UserRole.customer),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final customers = snapshot.data ?? [];
        if (customers.isEmpty) {
          return const EmptyState(
              message: 'لا يوجد زبائن مسجّلون.', icon: Icons.person_off);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: customers.length,
          itemBuilder: (context, i) {
            final c = customers[i];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.oliveDark,
                  child: Icon(Icons.person, color: AppColors.cream),
                ),
                title: Text(c.name,
                    style: const TextStyle(
                        color: AppColors.cream,
                        fontWeight: FontWeight.bold)),
                subtitle: Text(c.phone.isEmpty ? c.email : c.phone,
                    style: const TextStyle(color: AppColors.creamDim)),
                trailing: const Icon(Icons.account_balance_wallet,
                    color: AppColors.oliveBright),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text('ميزانية ${c.name}')),
                      body: CustomerOverview(
                        customerUid: c.uid,
                        customerName: c.name,
                        viewer: viewer,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
