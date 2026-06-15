import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/design_project.dart';
import '../../models/execution_report.dart';
import '../../models/expense.dart';
import '../../models/receipt.dart';
import '../../services/firestore_service.dart';
import '../../widgets/ui.dart';
import '../execution/receipt_detail_screen.dart';

/// لوحة تحكم الأدمن (T-1.5): مؤشرات لحظية + ملخص مالي + آخر التقارير والصرفيات.
/// كل الأرقام تُحدّث مباشرةً من Firestore عبر Streams.
class AdminOverview extends StatelessWidget {
  const AdminOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const PageHeader(
          title: 'لوحة التحكم',
          subtitle: 'نظرة عامة لحظية على المنشأة',
          icon: Icons.dashboard,
        ),
        const SizedBox(height: 14),

        // ---- مؤشرات العدّ ----
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            _CountTile(
              countStream: fs.allProjects().map((l) => l.length),
              label: 'مشاريع التصميم',
              icon: Icons.architecture,
            ),
            _CountTile(
              countStream: fs.allSites().map((l) => l.length),
              label: 'مواقع التنفيذ',
              icon: Icons.location_city,
            ),
            _CountTile(
              countStream:
                  fs.allUsers().map((l) => l.where((u) => u.isEmployee).length),
              label: 'الموظفون',
              icon: Icons.engineering,
              color: AppColors.oliveBright,
            ),
            _CountTile(
              countStream: fs.allUsers().map(
                  (l) => l.where((u) => u.role == UserRole.customer).length),
              label: 'الزبائن',
              icon: Icons.people,
              color: AppColors.oliveBright,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ---- الملخص المالي + المهام النشطة (من مشاريع التصميم) ----
        StreamBuilder<List<DesignProject>>(
          stream: fs.allProjects(),
          builder: (context, snap) {
            final projects = snap.data ?? const <DesignProject>[];
            num total = 0, paid = 0;
            var active = 0;
            for (final p in projects) {
              total += p.totalAmount;
              paid += p.paidAmount;
              if (p.remainingAmount > 0) active++;
            }
            return SectionCard(
              title: 'الملخص المالي للمشاريع',
              icon: Icons.account_balance_wallet,
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.35,
                children: [
                  StatTile(
                      value: '$active',
                      label: 'مشاريع نشطة',
                      icon: Icons.pending_actions,
                      color: AppColors.warning),
                  StatTile(
                      value: Fmt.money(total),
                      label: 'إجمالي العقود',
                      icon: Icons.summarize),
                  StatTile(
                      value: Fmt.money(paid),
                      label: 'المحصّل',
                      icon: Icons.price_check,
                      color: AppColors.success),
                  StatTile(
                      value: Fmt.money(total - paid),
                      label: 'المتبقي',
                      icon: Icons.account_balance,
                      color: AppColors.warning),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // ---- المدفوعات (الوصولات): الإجمالي + الأحدث من اشتراك واحد ----
        StreamBuilder<List<Receipt>>(
          stream: fs.allReceipts(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const EmptyState(
                  message: 'تعذّر تحميل الوصولات.', icon: Icons.error_outline);
            }
            final receipts = snap.data ?? const <Receipt>[];
            num total = 0;
            for (final r in receipts) {
              total += r.amount;
            }
            final recent = receipts.take(4).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionCard(
                  title: 'المدفوعات (الوصولات الإلكترونية)',
                  icon: Icons.receipt_long,
                  child: Column(
                    children: [
                      InfoRow(
                          label: 'عدد الوصولات',
                          value: '${receipts.length}'),
                      InfoRow(
                          label: 'إجمالي المدفوعات',
                          value: Fmt.money(total),
                          valueColor: AppColors.success),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle('آخر الوصولات'),
                if (snap.connectionState == ConnectionState.waiting)
                  const Padding(
                      padding: EdgeInsets.all(16), child: LoadingView())
                else if (recent.isEmpty)
                  const EmptyState(
                      message: 'لا توجد وصولات بعد.',
                      icon: Icons.receipt_long)
                else
                  ...recent.map((r) => _receiptTile(context, r)),
              ],
            );
          },
        ),
        const SizedBox(height: 12),

        // ---- آخر التقارير ----
        _sectionTitle('آخر تقارير التنفيذ'),
        StreamBuilder<List<ExecutionReport>>(
          stream: fs.allReports(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LoadingView(),
              );
            }
            final reports = (snap.data ?? const <ExecutionReport>[]).take(4);
            if (reports.isEmpty) {
              return const EmptyState(
                  message: 'لا توجد تقارير بعد.', icon: Icons.description);
            }
            return Column(children: reports.map(_reportTile).toList());
          },
        ),
        const SizedBox(height: 12),

        // ---- آخر الصرفيات/السلف ----
        _sectionTitle('آخر السلف والصرفيات'),
        StreamBuilder<List<Expense>>(
          stream: fs.allExpenses(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LoadingView(),
              );
            }
            final expenses = (snap.data ?? const <Expense>[]).take(4);
            if (expenses.isEmpty) {
              return const EmptyState(
                  message: 'لا توجد حركات مالية بعد.',
                  icon: Icons.receipt_long);
            }
            return Column(children: expenses.map(_expenseTile).toList());
          },
        ),
      ],
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 2),
        child: Text(t,
            style: const TextStyle(
                color: AppColors.cream,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      );

  Widget _receiptTile(BuildContext context, Receipt r) => Card(
        child: ListTile(
          leading:
              const Icon(Icons.receipt_long, color: AppColors.success),
          title: Text(Fmt.money(r.amount),
              style: const TextStyle(
                  color: AppColors.cream, fontWeight: FontWeight.bold)),
          subtitle: Text(
            '${r.ownerName.isEmpty ? (r.siteName.isEmpty ? '—' : r.siteName) : r.ownerName} • ${Fmt.date(r.date)}',
            style: const TextStyle(color: AppColors.creamDim),
          ),
          trailing:
              const Icon(Icons.chevron_left, color: AppColors.creamDim),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ReceiptDetailScreen(receipt: r)),
          ),
        ),
      );

  Widget _reportTile(ExecutionReport r) => Card(
        child: ListTile(
          leading: const Icon(Icons.description_outlined,
              color: AppColors.oliveBright),
          title: Text(r.siteName.isEmpty ? 'تقرير تنفيذ' : r.siteName,
              style: const TextStyle(
                  color: AppColors.cream, fontWeight: FontWeight.bold)),
          subtitle: Text(
            '${r.executorName.isEmpty ? '—' : r.executorName} • ${Fmt.date(r.date)}',
            style: const TextStyle(color: AppColors.creamDim),
          ),
        ),
      );

  Widget _expenseTile(Expense e) => Card(
        child: ListTile(
          leading: Icon(
            e.type == ExpenseType.advance
                ? Icons.account_balance_wallet_outlined
                : Icons.shopping_cart_outlined,
            color: e.type == ExpenseType.advance
                ? AppColors.warning
                : AppColors.oliveBright,
          ),
          title: Text('${e.type.labelAr}: ${Fmt.money(e.amount)}',
              style: const TextStyle(
                  color: AppColors.cream, fontWeight: FontWeight.bold)),
          subtitle: Text(
            '${e.siteName.isEmpty ? '—' : e.siteName} • ${Fmt.date(e.date)}',
            style: const TextStyle(color: AppColors.creamDim),
          ),
        ),
      );
}

/// مربع عدّاد لحظي يقرأ طول قائمة من Stream.
class _CountTile extends StatelessWidget {
  final Stream<int> countStream;
  final String label;
  final IconData icon;
  final Color? color;
  const _CountTile({
    required this.countStream,
    required this.label,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: countStream,
      builder: (context, snap) => StatTile(
        value: '${snap.data ?? 0}',
        label: label,
        icon: icon,
        color: color,
      ),
    );
  }
}
