import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/execution_report.dart';
import '../../models/receipt.dart';
import '../../models/work_site.dart';
import '../../services/firestore_service.dart';
import '../../widgets/execution_widgets.dart';
import '../../widgets/owner_account.dart';
import '../../widgets/receipt_tile.dart';
import '../../widgets/ui.dart';
import 'receipt_form.dart';
import 'report_form.dart';

/// تفاصيل موقع عمل: التقارير + الوصولات (الحضور يُسجَّل تلقائيًا بالموقع، فلا
/// يوجد تسجيل دخول يدوي للموقع). [interactive] = false عند العرض من المحاسبة/الزبون.
class SiteDetailScreen extends StatelessWidget {
  final WorkSite site;
  final AppUser user;
  final bool interactive;

  const SiteDetailScreen({
    super.key,
    required this.site,
    required this.user,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(site.siteName.isEmpty ? site.ownerName : site.siteName),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: AppColors.cream,
            unselectedLabelColor: AppColors.creamDim,
            indicatorColor: AppColors.oliveBright,
            tabs: [
              Tab(text: 'التقارير', icon: Icon(Icons.assignment)),
              Tab(text: 'الوصولات', icon: Icon(Icons.receipt_long)),
            ],
          ),
        ),
        body: Column(
          children: [
            _SiteHeader(site: site),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: OwnerAccountCard(ownerName: site.ownerName),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ReportsTab(
                      site: site, user: user, interactive: interactive),
                  _ReceiptsTab(
                      site: site, user: user, interactive: interactive),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteHeader extends StatelessWidget {
  final WorkSite site;
  const _SiteHeader({required this.site});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.oliveGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: AppColors.cream, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text('صاحب المشروع: ${site.ownerName}',
                    style: const TextStyle(
                        color: AppColors.cream, fontWeight: FontWeight.bold)),
              ),
              if (site.category.isPools)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(site.category.icon,
                          color: AppColors.cream, size: 14),
                      const SizedBox(width: 4),
                      Text(site.category.labelAr,
                          style: const TextStyle(
                              color: AppColors.cream,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          if (site.address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.place, color: Color(0xFFECEFE1), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(site.address,
                      style: const TextStyle(color: Color(0xFFECEFE1))),
                ),
              ],
            ),
          ],
          if (site.executorsLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.engineering,
                    color: Color(0xFFECEFE1), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      '${site.executorCount > 1 ? 'المنفّذون' : 'المنفّذ'}: ${site.executorsLabel}',
                      style: const TextStyle(color: Color(0xFFECEFE1))),
                ),
              ],
            ),
          ],
          if (site.durationDays != null) ...[
            const SizedBox(height: 6),
            Text('مدة التنفيذ المتوقعة: ${site.durationDays} يوم',
                style: const TextStyle(color: Color(0xFFECEFE1))),
          ],
        ],
      ),
    );
  }
}

/// تبويب التقارير اليومية.
class _ReportsTab extends StatelessWidget {
  final WorkSite site;
  final AppUser user;
  final bool interactive;
  const _ReportsTab(
      {required this.site, required this.user, required this.interactive});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return Column(
      children: [
        if (interactive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ReportForm(site: site, executor: user)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('تقرير يومي جديد'),
              ),
            ),
          ),
        Expanded(
          child: StreamBuilder<List<ExecutionReport>>(
            stream: fs.reportsBySite(site.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingView();
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const EmptyState(
                    message: 'لا توجد تقارير لهذا الموقع بعد.',
                    icon: Icons.assignment_outlined);
              }
              return ListView(
                padding: const EdgeInsets.all(12),
                children:
                    items.map((r) => ExecutionReportCard(report: r)).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// تبويب الوصولات الإلكترونية: إجمالي المدفوعات + قائمة الوصولات (T-3.6/T-3.7).
class _ReceiptsTab extends StatelessWidget {
  final WorkSite site;
  final AppUser user;
  final bool interactive;
  const _ReceiptsTab(
      {required this.site, required this.user, required this.interactive});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return Column(
      children: [
        if (interactive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ReceiptForm(site: site, executor: user)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('إصدار وصل إلكتروني'),
              ),
            ),
          ),
        Expanded(
          child: StreamBuilder<List<Receipt>>(
            stream: fs.receiptsBySite(site.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingView();
              }
              if (snapshot.hasError) {
                return const EmptyState(
                    message: 'تعذّر تحميل الوصولات.',
                    icon: Icons.error_outline);
              }
              final items = snapshot.data ?? [];
              num totalIn = 0, totalOut = 0;
              for (final r in items) {
                if (r.expense) {
                  totalOut += r.amount;
                } else {
                  totalIn += r.amount;
                }
              }
              final net = totalIn - totalOut;
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  SectionCard(
                    title: 'ملخّص الوصولات',
                    icon: Icons.summarize,
                    child: Column(
                      children: [
                        InfoRow(
                            label: 'عدد الوصولات', value: '${items.length}'),
                        InfoRow(
                            label: 'إجمالي القبض',
                            value: Fmt.money(totalIn),
                            valueColor: AppColors.success),
                        InfoRow(
                            label: 'إجمالي الصرف',
                            value: Fmt.money(totalOut),
                            valueColor: AppColors.danger),
                        InfoRow(
                            label: 'الصافي',
                            value: Fmt.money(net),
                            valueColor: net >= 0
                                ? AppColors.success
                                : AppColors.danger),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    const EmptyState(
                        message: 'لا توجد وصولات لهذا الموقع بعد.',
                        icon: Icons.receipt_long)
                  else
                    ...items.map((r) => ReceiptTile(receipt: r)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}


