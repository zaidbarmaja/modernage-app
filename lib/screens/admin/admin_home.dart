import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../widgets/app_actions.dart';
import '../../widgets/notifications_view.dart';
import '../design/design_project_form.dart';
import 'add_customer_form.dart';
import 'add_employee_form.dart';
import 'add_site_form.dart';
import 'admin_comprehensive_board.dart';
import 'admin_control.dart';
import 'admin_overview.dart';
import 'admin_projects.dart';
import 'users_management.dart';

/// الصفحة الرئيسية للإدارة:
/// نظرة عامة لحظية + كل المشاريع (تصميم/تنفيذ) + المستخدمون + الإشعارات.
class AdminHome extends StatefulWidget {
  final AppUser user;
  const AdminHome({super.key, required this.user});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _index = 0;

  static const _titles = [
    'نظرة عامة',
    'المشاريع',
    'المستخدمون',
    'التقارير',
    'الإعدادات',
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const AdminOverview(),
      AdminProjectsView(user: widget.user),
      UsersManagementTab(currentUid: widget.user.uid),
      const AdminComprehensiveBoard(),
      AdminControlHub(user: widget.user),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('الإدارة • ${_titles[_index]}'),
        actions: [
          IconButton(
            tooltip: 'الإشعارات',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('الإشعارات')),
                  body: const NotificationsView(),
                ),
              ),
            ),
          ),
          const LogoutAction(),
        ],
      ),
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.olive,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined), label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.architecture), label: 'المشاريع'),
          NavigationDestination(icon: Icon(Icons.people), label: 'المستخدمون'),
          NavigationDestination(
              icon: Icon(Icons.event_note), label: 'التقارير'),
          NavigationDestination(
              icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
      floatingActionButton: switch (_index) {
        1 => FloatingActionButton.extended(
            onPressed: () => _showCreateProjectSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('مشروع'),
          ),
        2 => FloatingActionButton.extended(
            onPressed: () => _showAddUserSheet(context),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('إضافة'),
          ),
        _ => null,
      },
    );
  }

  void _showAddUserSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.engineering, color: AppColors.oliveBright),
              title: const Text('إضافة موظف',
                  style: TextStyle(color: AppColors.cream)),
              subtitle: const Text('مصمم / تنفيذ / محاسبة',
                  style: TextStyle(color: AppColors.creamDim)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddEmployeeForm()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: AppColors.oliveBright),
              title: const Text('إضافة زبون',
                  style: TextStyle(color: AppColors.cream)),
              subtitle: const Text('دخول بالهاتف ورمز الوصول (قراءة فقط)',
                  style: TextStyle(color: AppColors.creamDim)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddCustomerForm()));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateProjectSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.architecture, color: AppColors.oliveBright),
              title: const Text('مشروع تصميم',
                  style: TextStyle(color: AppColors.cream)),
              subtitle: const Text('المتطلبات + إسناد لمصمم + ربط زبون',
                  style: TextStyle(color: AppColors.creamDim)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DesignProjectForm()));
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.location_city, color: AppColors.oliveBright),
              title: const Text('مشروع تنفيذ (موقع عمل)',
                  style: TextStyle(color: AppColors.cream)),
              subtitle: const Text('موقع GPS + إسناد منفّذ + ربط زبون',
                  style: TextStyle(color: AppColors.creamDim)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddSiteForm()));
              },
            ),
          ],
        ),
      ),
    );
  }
}
