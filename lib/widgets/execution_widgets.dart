import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/execution_report.dart';
import '../models/expense.dart';
import '../models/site_checkin.dart';
import 'ui.dart';

/// صف صور أفقي قابل للنقر لعرضها بملء الشاشة.
class NetworkPhotosRow extends StatelessWidget {
  final List<String> urls;
  const NetworkPhotosRow({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => _openFull(context, urls[i]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              urls[i],
              width: 92,
              height: 92,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 92,
                height: 92,
                color: AppColors.surfaceAlt,
                child: const Icon(Icons.broken_image,
                    color: AppColors.creamDim),
              ),
              loadingBuilder: (c, child, progress) => progress == null
                  ? child
                  : Container(
                      width: 92,
                      height: 92,
                      color: AppColors.surfaceAlt,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.oliveBright),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _openFull(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: Image.network(url)),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة تقرير تنفيذ يومي.
class ExecutionReportCard extends StatelessWidget {
  final ExecutionReport report;
  const ExecutionReportCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'تقرير ${Fmt.date(report.date)}',
      icon: Icons.assignment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (report.documentsNotes.isNotEmpty)
            _block('المستندات والملاحظات', report.documentsNotes),
          if (report.plannedNextDays.isNotEmpty)
            _block('أعمال الأيام القادمة', report.plannedNextDays),
          if (report.durationDays != null)
            InfoRow(
                label: 'مدة تنفيذ هذا العمل',
                value: '${report.durationDays} يوم'),
          if (report.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('الصور اليومية:',
                style: TextStyle(color: AppColors.creamDim, fontSize: 13)),
            const SizedBox(height: 6),
            NetworkPhotosRow(urls: report.photoUrls),
          ],
        ],
      ),
    );
  }

  Widget _block(String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: AppColors.oliveBright,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(body,
                style: const TextStyle(color: AppColors.cream, height: 1.5)),
          ],
        ),
      );
}

/// عنصر تسجيل دخول موقع.
class SiteCheckinTile extends StatelessWidget {
  final SiteCheckin checkin;
  const SiteCheckinTile({super.key, required this.checkin});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.location_on, color: AppColors.success),
        title: Text(Fmt.dateTime(checkin.time),
            style: const TextStyle(
                color: AppColors.cream, fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${checkin.executorName}\n'
          '${checkin.address.isEmpty ? '' : '${checkin.address}\n'}'
          'الإحداثيات: ${checkin.lat.toStringAsFixed(5)}, ${checkin.lng.toStringAsFixed(5)}',
          style: const TextStyle(color: AppColors.creamDim, height: 1.5),
        ),
        isThreeLine: true,
      ),
    );
  }
}

/// عنصر سلفة/صرفية.
class ExpenseTile extends StatelessWidget {
  final Expense expense;
  const ExpenseTile({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    final isAdvance = expense.type == ExpenseType.advance;
    final color = isAdvance ? AppColors.warning : AppColors.danger;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(isAdvance ? Icons.account_balance_wallet : Icons.shopping_cart,
              color: color, size: 20),
        ),
        title: Text(Fmt.money(expense.amount),
            style: const TextStyle(
                color: AppColors.cream, fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${expense.type.labelAr}'
          '${expense.note.isEmpty ? '' : ' • ${expense.note}'}\n${Fmt.date(expense.date)}',
          style: const TextStyle(color: AppColors.creamDim, height: 1.5),
        ),
        isThreeLine: true,
      ),
    );
  }
}
