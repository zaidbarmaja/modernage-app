import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/work_site.dart';
import '../../services/firestore_service.dart';
import '../../services/notifications.dart';
import '../../widgets/app_actions.dart';
import '../../widgets/notifications_view.dart';
import '../../widgets/site_card.dart';
import '../../widgets/ui.dart';
import '../attendance/attendance_view.dart';
import 'site_detail_screen.dart';

/// الصفحة الرئيسية لموظف التنفيذ: تبويبان فقط — «الرئيسية» (ملخّص) و«مواقعي».
/// كل العمليات (تسجيل الدخول/البصمة، التقارير، الوصولات) تتم بالضغط على الموقع
/// من تبويب «مواقعي». الصفحة الرئيسية تعرض الملخّص فقط بلا بصمة.
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
    return Scaffold(
      appBar: AppBar(
        title: Text(const ['الرئيسية', 'مواقعي'][_index]),
        actions: [
          IconButton(
            tooltip: 'الإشعارات',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('الإشعارات')),
                  body: NotificationsView(
                      stream: Notifications.streamFor(widget.user.uid)),
                ),
              ),
            ),
          ),
          const LogoutAction(),
        ],
      ),
      // بناء كسول: يُبنى التبويب الظاهر فقط لتقليل قراءات Firestore.
      // «الرئيسية» تعرض ملخّص الحضور بنفس مكوّن صفحة موظف التصميم (AttendanceTab).
      body: _index == 0
          ? AttendanceTab(user: widget.user)
          : _SitesTab(user: widget.user),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.olive,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.engineering), label: 'مواقعي'),
        ],
      ),
    );
  }
}

/// تبويب «مواقعي»: مواقع العمل المسندة للموظف، مجمّعة حسب الفئة.
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
