import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/work_site.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_actions.dart';
import '../../widgets/site_card.dart';
import '../../widgets/ui.dart';
import '../attendance/attendance_view.dart';
import '../reports/daily_reports_view.dart';
import 'site_detail_screen.dart';

/// الصفحة الرئيسية لموظف التنفيذ: البصمة + مواقع العمل المسندة إليه.
class ExecutionHome extends StatefulWidget {
  final AppUser user;
  const ExecutionHome({super.key, required this.user});

  @override
  State<ExecutionHome> createState() => _ExecutionHomeState();
}

class _ExecutionHomeState extends State<ExecutionHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _AttendanceTab(user: widget.user),
      _SitesTab(user: widget.user),
      DailyReportsView(user: widget.user),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(const ['البصمة', 'مواقع العمل', 'تقاريري'][_index]),
        actions: const [LogoutAction()],
      ),
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.olive,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.fingerprint), label: 'البصمة'),
          NavigationDestination(
              icon: Icon(Icons.engineering), label: 'مواقعي'),
          NavigationDestination(
              icon: Icon(Icons.event_note), label: 'تقاريري'),
        ],

      ),
    );
  }
}

/// تبويب البصمة لموظف التنفيذ: يجلب مواقعه المسندة ويمرّرها لشاشة البصمة
/// لفرض النطاق الجغرافي (التسجيل من داخل الموقع فقط — T-3.1).
class _AttendanceTab extends StatelessWidget {
  final AppUser user;
  const _AttendanceTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<WorkSite>>(
      stream: fs.sitesByExecutor(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        return AttendanceView(
          user: user,
          geofenceSites: snapshot.data ?? const [],
          enforceGeofence: true,
        );
      },
    );
  }
}

class _SitesTab extends StatelessWidget {
  final AppUser user;
  const _SitesTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<WorkSite>>(
      stream: fs.sitesByExecutor(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final sites = snapshot.data ?? [];
        if (sites.isEmpty) {
          return const EmptyState(
            message:
                'لا توجد مواقع مسندة إليك بعد.\nتقوم الإدارة بإضافة مواقع العمل وإسنادها إليك.',
            icon: Icons.location_city,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: sites.length,
          itemBuilder: (context, i) => SiteCard(
            site: sites[i],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SiteDetailScreen(site: sites[i], user: user),
              ),
            ),
          ),
        );
      },
    );
  }
}
