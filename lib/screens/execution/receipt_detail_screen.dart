import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/receipt.dart';
import '../../services/receipt_pdf.dart';
import '../../widgets/ui.dart';

/// تفاصيل وصل إلكتروني + تصدير/مشاركة نسخة PDF (T-3.9).
class ReceiptDetailScreen extends StatefulWidget {
  final Receipt receipt;
  const ReceiptDetailScreen({super.key, required this.receipt});

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  bool _exporting = false;

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      await ReceiptPdf.share(widget.receipt);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر توليد ملف PDF.', error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.receipt;
    return Scaffold(
      appBar: AppBar(title: Text('وصل رقم ${r.shortNo}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.oliveGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('المبلغ المدفوع',
                      style: TextStyle(color: Color(0xFFE9E3CF))),
                  const SizedBox(height: 6),
                  Text(Fmt.money(r.amount),
                      style: const TextStyle(
                          color: AppColors.cream,
                          fontSize: 30,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'تفاصيل الوصل',
              icon: Icons.receipt_long,
              child: Column(
                children: [
                  InfoRow(label: 'التاريخ', value: Fmt.date(r.date)),
                  InfoRow(
                      label: 'صاحب المشروع',
                      value: r.ownerName.isEmpty ? '—' : r.ownerName),
                  InfoRow(
                      label: 'الموقع',
                      value: r.siteName.isEmpty ? '—' : r.siteName),
                  InfoRow(
                      label: 'الوصف',
                      value: r.description.isEmpty ? '—' : r.description),
                  InfoRow(
                      label: 'المُصدِر',
                      value: r.createdByName.isEmpty ? '—' : r.createdByName),
                ],
              ),
            ),
            if (r.imageUrl.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('مرفق الوصل',
                  style: TextStyle(
                      color: AppColors.cream, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  r.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) =>
                      progress == null
                          ? child
                          : const Padding(
                              padding: EdgeInsets.all(24),
                              child: LoadingView()),
                  errorBuilder: (context, _, _) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('تعذّر تحميل الصورة.',
                        style: TextStyle(color: AppColors.creamDim)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _exporting ? null : _exportPdf,
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: AppColors.cream, strokeWidth: 2.2))
                  : const Icon(Icons.picture_as_pdf),
              label: Text(_exporting ? 'جارٍ التوليد...' : 'تصدير / مشاركة PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
