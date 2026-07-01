import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/receipt.dart';
import '../screens/execution/receipt_detail_screen.dart';
import '../services/firestore_service.dart';
import '../services/receipt_pdf.dart';

/// عنصر وصل إلكتروني قابل لإعادة الاستخدام: يعرض النوع (قبض/صرف) والمبلغ
/// والمستلِم والوصف، مع زر **مشاركة** (PDF)، وزر **حذف** اختياري (يحذف الوصل
/// ونسخته في الحسابات/الدفع الإلكتروني معًا)، وفتح التفاصيل بالضغط.
class ReceiptTile extends StatelessWidget {
  final Receipt receipt;

  /// يعرض اسم صاحب المشروع/الزبون (مفيد في صفحة الحسابات العامة).
  final bool showOwner;

  /// يُظهر زر الحذف (يُحذف الوصل ومرآته في الحسابات معًا).
  final bool canDelete;

  const ReceiptTile({
    super.key,
    required this.receipt,
    this.showOwner = false,
    this.canDelete = false,
  });

  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
        content: Text('جارٍ تحضير الوصل للمشاركة…'),
        duration: Duration(seconds: 2)));
    try {
      await ReceiptPdf.share(receipt);
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('تعذّر مشاركة الوصل: $e')));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('حذف الوصل', style: TextStyle(color: AppColors.cream)),
          content: Text(
            'حذف وصل ${receipt.shortNo} بمبلغ ${Fmt.money(receipt.amount)}؟\n'
            'سيُحذف أيضًا من الحسابات والدفع الإلكتروني. لا يمكن التراجع.',
            style: const TextStyle(color: AppColors.creamDim, height: 1.6),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء',
                    style: TextStyle(color: AppColors.creamDim))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف',
                    style: TextStyle(color: AppColors.danger))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await FirestoreService().deleteReceipt(receipt.id);
      messenger.showSnackBar(const SnackBar(content: Text('تم حذف الوصل ✓')));
    } catch (_) {
      messenger
          .showSnackBar(const SnackBar(content: Text('تعذّر حذف الوصل.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = receipt;
    final expense = r.expense;
    final color = expense ? AppColors.danger : AppColors.success;
    final kind = expense ? 'صرف' : 'قبض';
    final lines = <String>[
      if (showOwner && r.ownerName.isNotEmpty) r.ownerName,
      if (r.recipient.isNotEmpty) 'المستلِم: ${r.recipient}',
      if (r.description.isNotEmpty) r.description else 'وصل',
      'رقم ${r.shortNo} • ${Fmt.date(r.date)}',
    ];
    return Card(
      child: ListTile(
        leading: r.imageUrl.isEmpty
            ? Icon(expense ? Icons.north_east : Icons.south_west, color: color)
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(r.imageUrl,
                    width: 44, height: 44, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Icon(
                        expense ? Icons.north_east : Icons.south_west,
                        color: color)),
              ),
        title: Text('$kind: ${Fmt.money(r.amount)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        subtitle: Text(lines.join('\n'),
            style: const TextStyle(color: AppColors.creamDim, height: 1.4)),
        isThreeLine: lines.length > 2,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.share, color: AppColors.oliveBright),
              tooltip: 'مشاركة الوصل (PDF)',
              onPressed: () => _share(context),
            ),
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                tooltip: 'حذف الوصل',
                onPressed: () => _delete(context),
              ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ReceiptDetailScreen(receipt: receipt)),
        ),
      ),
    );
  }
}
