import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/format.dart';
import '../models/receipt.dart';

/// توليد نسخة PDF لوصل إلكتروني (عربية RTL بخط Tajawal) ومشاركتها/طباعتها.
class ReceiptPdf {
  ReceiptPdf._();

  static const _olive = PdfColor.fromInt(0xFF6B7A4F);
  static const _ink = PdfColor.fromInt(0xFF2A2A22);

  /// يبني بايتات ملف PDF للوصل.
  static Future<Uint8List> build(Receipt r) async {
    final regular =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
    final bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);

    pw.ImageProvider? image;
    if (r.imageUrl.isNotEmpty) {
      try {
        image = await networkImage(r.imageUrl);
      } catch (_) {
        image = null; // قد يتعذّر جلب الصورة بلا إنترنت — نتجاهلها.
      }
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        footer: (context) => pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Divider(color: _olive),
            pw.Text(
              'هذا الوصل وثيقة إلكترونية صادرة من تطبيق «عصر الحداثة».',
              style: pw.TextStyle(
                  font: regular, fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (context) => [
          _header(r),
          pw.SizedBox(height: 18),
          _amountBox(r),
          pw.SizedBox(height: 18),
          _row('التاريخ', Fmt.date(r.date)),
          _row('صاحب المشروع', r.ownerName.isEmpty ? '—' : r.ownerName),
          _row('الموقع', r.siteName.isEmpty ? '—' : r.siteName),
          _row('الوصف', r.description.isEmpty ? '—' : r.description),
          _row('المُصدِر', r.createdByName.isEmpty ? '—' : r.createdByName),
          if (image != null) ...[
            pw.SizedBox(height: 16),
            pw.Text('مرفق الوصل:',
                style: pw.TextStyle(font: bold, color: _ink)),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Container(
                constraints: const pw.BoxConstraints(maxHeight: 280),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _olive, width: 0.7),
                ),
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  /// يفتح حوار المشاركة/الطباعة للوصل.
  static Future<void> share(Receipt r) async {
    final bytes = await build(r);
    await Printing.sharePdf(bytes: bytes, filename: 'receipt_${r.shortNo}.pdf');
  }

  static pw.Widget _header(Receipt r) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: const pw.BoxDecoration(color: _olive),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('عصر الحداثة',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Text('ModernAge',
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('وصل إلكتروني',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Text('رقم: ${r.shortNo}',
                        style: const pw.TextStyle(
                            color: PdfColors.white, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      );

  static pw.Widget _amountBox(Receipt r) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 16),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFEFF1E8),
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          children: [
            pw.Text('المبلغ المدفوع',
                style: const pw.TextStyle(fontSize: 11, color: _ink)),
            pw.SizedBox(height: 4),
            pw.Text(Fmt.money(r.amount),
                style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                    color: _olive)),
          ],
        ),
      );

  static pw.Widget _row(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 110,
              child: pw.Text('$label:',
                  style: const pw.TextStyle(color: PdfColors.grey700)),
            ),
            pw.Expanded(
              child: pw.Text(value,
                  style: pw.TextStyle(
                      color: _ink, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
      );
}
