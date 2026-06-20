import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/design_project.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_actions.dart';
import '../../widgets/project_card.dart';
import '../../widgets/ui.dart';
import '../attendance/attendance_view.dart';
import '../reports/daily_reports_view.dart';
import 'design_project_detail.dart';
import 'design_project_form.dart';

/// الصفحة الرئيسية لموظف التصميم: البصمة + مشاريعي.
class DesignHome extends StatefulWidget {
  final AppUser user;
  const DesignHome({super.key, required this.user});

  @override
  State<DesignHome> createState() => _DesignHomeState();
}

class _DesignHomeState extends State<DesignHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      AttendanceTab(user: widget.user),
      _ProjectsTab(user: widget.user),
      DailyReportsView(user: widget.user),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(const ['البصمة', 'المشاريع', 'تقاريري'][_index]),
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
              icon: Icon(Icons.architecture), label: 'المشاريع'),
          NavigationDestination(
              icon: Icon(Icons.event_note), label: 'تقاريري'),
        ],
      ),
      floatingActionButton: _index == 1
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        DesignProjectForm(designer: widget.user)),
              ),
              icon: const Icon(Icons.add),
              label: const Text('إضافة مشروع'),
            )
          : null,
    );
  }
}

class _ProjectsTab extends StatelessWidget {
  final AppUser user;
  const _ProjectsTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<DesignProject>>(
      stream: fs.projectsByDesigner(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final projects = snapshot.data ?? [];
        if (projects.isEmpty) {
          return const EmptyState(
            message: 'لا توجد مشاريع بعد.\nاضغط "إضافة مشروع" لإضافة أول مشروع.',
            icon: Icons.architecture,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: projects.length,
          itemBuilder: (context, i) {
            final p = projects[i];
            return ProjectCard(
              project: p,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DesignProjectDetail(
                      projectId: p.id, editor: user, authorName: user.name),
                ),
              ),
              onEdit: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DesignProjectForm(designer: user, existing: p),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
