import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/execution_report.dart';
import '../../models/work_site.dart';
import '../../services/firestore_service.dart';
import '../../widgets/execution_widgets.dart';
import '../../widgets/ui.dart';

/// عرض الزبون لتقدّم موقع تنفيذه: نسبة الإنجاز التقديرية + تقارير العمل وصورها.
/// قراءة فقط — لا يملك الزبون أي إجراء تشغيلي على الموقع.
class CustomerSiteScreen extends StatelessWidget {
  final WorkSite site;
  final String customerUid;
  const CustomerSiteScreen(
      {super.key, required this.site, required this.customerUid});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final title = site.siteName.isEmpty ? site.ownerName : site.siteName;
    final progress = site.autoProgressPercent;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        // استعلام مُقيَّد بـ customerUid (تسمح به القواعد)، ثم فلترة حسب الموقع.
        child: StreamBuilder<List<ExecutionReport>>(
          stream: fs.reportsByCustomer(customerUid),
          builder: (context, snap) {
            final reports = (snap.data ?? const <ExecutionReport>[])
                .where((r) => r.siteId == site.id)
                .toList();
            final waiting = snap.connectionState == ConnectionState.waiting;
            return ListView(
              padding: const EdgeInsets.all(14),
              children: [
                PageHeader(
                  title: title,
                  subtitle: 'تقدّم العمل وصوره',
                  icon: Icons.location_city,
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'حالة الموقع',
                  icon: Icons.insights,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (progress != null) ...[
                        ProgressBar(
                            percent: progress,
                            label: 'نسبة الإنجاز التقديرية'),
                        const SizedBox(height: 12),
                      ],
                      InfoRow(label: 'صاحب المشروع', value: site.ownerName),
                      if (site.address.isNotEmpty)
                        InfoRow(label: 'العنوان', value: site.address),
                      if (site.executorsLabel.isNotEmpty)
                        InfoRow(
                            label:
                                site.executorCount > 1 ? 'المنفّذون' : 'المنفّذ',
                            value: site.executorsLabel),
                      if (site.durationDays != null)
                        InfoRow(
                            label: 'المدّة المتوقعة',
                            value: '${site.durationDays} يوم'),
                      InfoRow(
                          label: 'عدد التقارير', value: '${reports.length}'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('تقارير العمل والصور',
                    style: TextStyle(
                        color: AppColors.cream,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (waiting)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: LoadingView(),
                  )
                else if (snap.hasError)
                  const EmptyState(
                      message: 'تعذّر تحميل التقارير.',
                      icon: Icons.error_outline)
                else if (reports.isEmpty)
                  const EmptyState(
                      message: 'لا توجد تقارير لهذا الموقع بعد.',
                      icon: Icons.assignment_outlined)
                else
                  ...reports.map((r) => ExecutionReportCard(report: r)),
              ],
            );
          },
        ),
      ),
    );
  }
}
