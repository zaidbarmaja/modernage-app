import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../widgets/app_actions.dart';
import '../../widgets/notifications_view.dart';
import '../design/design_project_form.dart';
import 'accounts_receipts_screen.dart';
import 'add_site_form.dart';
import 'admin_attendance.dart';
import 'admin_control.dart';
import 'admin_projects.dart';
import 'admin_reports.dart';

/// الصفحة الرئيسية للإدارة — شريط تنقّل سفلي بخمسة أقسام:
/// المالية (الوصولات والحسابات) · المشاريع · التقارير · البصمة · الإعدادات.
class AdminHome extends StatefulWidget {
  final AppUser user;
  const AdminHome({super.key, required this.user});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _index = 0;

  static const _titles = [
    'الحسابات',
    'المشاريع',
    'التقارير',
    'البصمة',
    'الإعدادات',
  ];

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    // بناء كسول: يُبنى التبويب النشط فقط (لا تبقى مستمعات Firestore لكل التبويبات
    // نشطة معًا) — يقلّل قراءات قاعدة البيانات بشكل كبير.
    final body = switch (_index) {
      0 => AccountsReceiptsView(user: widget.user),
      1 => AdminProjectsView(user: widget.user),
      2 => const AdminReportsView(),
      3 => const AdminAttendanceScreen(),
      _ => AdminControlHub(user: widget.user),
    };
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
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.olive,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet), label: 'الحسابات'),
          NavigationDestination(
              icon: Icon(Icons.architecture), label: 'المشاريع'),
          NavigationDestination(
              icon: Icon(Icons.event_note), label: 'التقارير'),
          NavigationDestination(
              icon: Icon(Icons.fingerprint), label: 'البصمة'),
          NavigationDestination(
              icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
      // زر إضافة مشروع يظهر فقط في تبويب المشاريع.
      floatingActionButton: _index == 1
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateProjectSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('مشروع'),
            )
          : null,
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
