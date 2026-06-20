import 'package:flutter/material.dart';

import '../../core/constants.dart';
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
      AttendanceTab(user: widget.user),
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
        if (snapshot.hasError) {
          return const EmptyState(
              message: 'تعذّر تحميل المواقع.', icon: Icons.error_outline);
        }
        final sites = snapshot.data ?? [];
        if (sites.isEmpty) {
          return const EmptyState(
            message:
                'لا توجد مواقع مسندة إليك بعد.\nتقوم الإدارة بإضافة مواقع العمل وإسنادها إليك.',
            icon: Icons.location_city,
          );
        }
        // تجميع المواقع حسب قسم التنفيذ (عام / إشراف مسابح / تنفيذ مسابح).
        final children = <Widget>[];
        for (final cat in WorkCategory.values) {
          final group = sites.where((s) => s.category == cat).toList();
          if (group.isEmpty) continue;
          children.add(_categoryHeader(cat, group.length));
          children.addAll(group.map((s) => SiteCard(
                site: s,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SiteDetailScreen(site: s, user: user),
                  ),
                ),
              )));
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: children,
        );
      },
    );
  }

  Widget _categoryHeader(WorkCategory cat, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
        child: Row(
          children: [
            Icon(cat.icon, size: 18, color: AppColors.oliveBright),
            const SizedBox(width: 6),
            Text('${cat.labelAr} ($count)',
                style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
