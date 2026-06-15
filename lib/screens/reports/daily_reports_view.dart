import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/daily_report.dart';
import '../../services/firestore_service.dart';
import '../../widgets/ui.dart';
import 'daily_report_form.dart';

/// شاشة التقارير اليومية للموظف: تقرير اليوم (كتابة/تعديل) + التقارير السابقة.
class DailyReportsView extends StatelessWidget {
  final AppUser user;
  const DailyReportsView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<List<DailyReport>>(
      stream: fs.dailyReportsByUser(user.uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final reports = snap.data ?? [];
        final todayKey = DailyReport.dayKeyOf(DateTime.now());
        final today = reports
            .cast<DailyReport?>()
            .firstWhere((r) => r?.dayKey == todayKey, orElse: () => null);
        final past = reports.where((r) => r.dayKey != todayKey).toList();

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const PageHeader(
              title: 'التقرير اليومي',
              subtitle: 'سجّل ما أنجزته كل يوم',
              icon: Icons.event_note,
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'تقرير اليوم • ${Fmt.date(DateTime.now())}',
              icon: Icons.today,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (today == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('لم تكتب تقرير اليوم بعد.',
                          style: TextStyle(color: AppColors.creamDim)),
                    )
                  else ...[
                    Text(today.content,
                        style: const TextStyle(
                            color: AppColors.cream, height: 1.6)),
                    if (today.projectName.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('🔗 ${today.projectName}',
                          style: const TextStyle(
                              color: AppColors.oliveBright, fontSize: 13)),
                    ],
                  ],
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DailyReportForm(user: user, existing: today),
                      ),
                    ),
                    icon: Icon(
                        today == null ? Icons.edit_note : Icons.edit, size: 18),
                    label:
                        Text(today == null ? 'اكتب تقرير اليوم' : 'تعديل تقرير اليوم'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('تقاريري السابقة',
                style: TextStyle(
                    color: AppColors.cream,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (past.isEmpty)
              const EmptyState(
                  message: 'لا توجد تقارير سابقة.', icon: Icons.event_note)
            else
              ...past.map((r) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.event_note,
                          color: AppColors.oliveBright),
                      title: Text(Fmt.date(r.date),
                          style: const TextStyle(
                              color: AppColors.cream,
                              fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          r.projectName.isNotEmpty
                              ? '🔗 ${r.projectName}\n${r.content}'
                              : r.content,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.creamDim)),
                    ),
                  )),
          ],
        );
      },
    );
  }
}
