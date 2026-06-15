import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/firebase_service.dart';
import '../theme.dart';
import '../utils/time_utils.dart';
import '../widgets/common.dart';

/// نافذة إضافة/تعديل وصل دفع إلكتروني.
/// «الدافع» يُملأ تلقائيًا باسم الموظف عند الإضافة.
Future<void> receiptDialog(
  BuildContext context, {
  required String projectId,
  required String projectCollection,
  required String employeeId,
  required String employeeName,
  required String ownerName,
  required String currency,
  String ownerPhone = '',
  Map<String, dynamic>? existing,
  String? receiptId,
}) async {
  final isEdit = existing != null && receiptId != null;
  final oldAmount =
      (existing?['amount'] is num) ? (existing!['amount'] as num).toInt() : 0;
  final amount =
      TextEditingController(text: oldAmount == 0 ? '' : '$oldAmount');
  final payer = TextEditingController(
      text: isEdit ? '${existing['payer'] ?? ''}' : employeeName);
  final note =
      TextEditingController(text: isEdit ? '${existing['note'] ?? ''}' : '');
  DateTime date = isEdit
      ? (DateTime.tryParse('${existing['date']}') ?? DateTime.now())
      : DateTime.now();
  var busy = false;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
      Future<void> save() async {
        final amt = int.tryParse(amount.text.trim()) ?? 0;
        if (amt <= 0) {
          ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('أدخل مبلغًا صحيحًا.')));
          return;
        }
        setLocal(() => busy = true);
        try {
          if (isEdit) {
            await Db.updateReceipt(
              receiptId,
              projectCollection,
              projectId,
              oldAmount: oldAmount,
              newAmount: amt,
              payer: payer.text.trim(),
              note: note.text.trim(),
              dateIso: date.toIso8601String(),
            );
          } else {
            await Db.addReceipt(
              projectId: projectId,
              projectCollection: projectCollection,
              employeeId: employeeId,
              ownerName: ownerName,
              ownerPhone: ownerPhone,
              amount: amt,
              currency: currency,
              payer: payer.text.trim(),
              note: note.text.trim(),
              dateIso: date.toIso8601String(),
            );
          }
          if (ctx.mounted) Navigator.pop(ctx);
        } catch (_) {
          setLocal(() => busy = false);
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('تعذّر حفظ الوصل. حاول مجددًا.')));
          }
        }
      }

      return Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(isEdit ? 'تعديل الوصل' : 'إضافة وصل إلكتروني'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: payer,
                  decoration: const InputDecoration(labelText: 'الدافع'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (p != null) {
                      setLocal(() => date = DateTime(
                          p.year, p.month, p.day, date.hour, date.minute,
                          date.second));
                    }
                  },
                  icon: const Icon(Icons.event, size: 16),
                  label: Text(
                      'التاريخ: ${ArDate.dateOnly(date)} · ${ArDate.timeOnly(date)}'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: 'المبلغ المدفوع (${currencyName(currency)})'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'وذلك عن'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
                onPressed: busy ? null : save,
                child: Text(isEdit ? 'حفظ' : 'حفظ الوصل')),
          ],
        ),
      );
    }),
  );
}

/// قائمة وصولات المشروع.
class ReceiptsList extends StatelessWidget {
  final String projectId;
  final String projectCollection;
  final String projectName;
  final bool canManage;
  const ReceiptsList({
    required this.projectId,
    required this.projectCollection,
    required this.projectName,
    this.canManage = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: Db.receipts.where('projectId', isEqualTo: projectId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LoadingView(),
          );
        }
        final docs = snap.data!.docs.toList()
          ..sort((a, b) {
            final da = DateTime.tryParse('${a.data()['date']}') ?? DateTime(0);
            final db = DateTime.tryParse('${b.data()['date']}') ?? DateTime(0);
            return db.compareTo(da);
          });
        if (docs.isEmpty) {
          return const Text('لا توجد وصولات بعد.',
              style: TextStyle(color: AppColors.muted));
        }
        return Column(
          children: [for (final r in docs) _tile(context, r)],
        );
      },
    );
  }

  Widget _tile(
      BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> r) {
    final d = r.data();
    final amount = (d['amount'] is num) ? (d['amount'] as num).toInt() : 0;
    final currency = (d['currency'] ?? 'IQD').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cream50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.green100,
          child: Icon(Icons.receipt_long,
              color: AppColors.green700, size: 20),
        ),
        title: Text(moneyLabel(amount, currency),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
            '${ArDate.dateOnly(d['date'])} · ${ArDate.timeOnly(d['date'])} · ${d['payer'] ?? ''}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ReceiptView(
            data: d,
            receiptId: r.id,
            projectName: projectName,
            projectCollection: projectCollection,
            canManage: canManage,
          ),
        )),
      ),
    );
  }
}

/// عرض الوصل على الشاشة مع زر تنزيل PDF (وتعديل/حذف للمدير).
class ReceiptView extends StatefulWidget {
  final Map<String, dynamic> data;
  final String receiptId;
  final String projectName;
  final String projectCollection;
  final bool canManage;
  const ReceiptView({
    required this.data,
    required this.receiptId,
    required this.projectName,
    required this.projectCollection,
    this.canManage = false,
    super.key,
  });

  @override
  State<ReceiptView> createState() => _ReceiptViewState();
}

class _ReceiptViewState extends State<ReceiptView> {
  final _boundaryKey = GlobalKey();
  bool _busy = false;

  Future<Uint8List?> _pdfBytes() async {
    final boundary =
        _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = bytes!.buffer.asUint8List();
    final pdf = pw.Document();
    final pdfImage = pw.MemoryImage(pngBytes);
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      build: (c) => pw.Center(child: pw.Image(pdfImage)),
    ));
    return pdf.save();
  }

  String _fileName() {
    final owner = '${widget.data['ownerName'] ?? 'العميل'}'.trim();
    return 'وصل-عصر-الحداثة-$owner.pdf';
  }

  Future<void> _sharePdf() async {
    setState(() => _busy = true);
    try {
      final bytes = await _pdfBytes();
      if (bytes == null) return;
      await Printing.sharePdf(bytes: bytes, filename: _fileName());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذّر إنشاء/مشاركة ملف PDF.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// تطبيع رقم الهاتف العراقي إلى صيغة واتساب الدولية (964…).
  String _waNumber(String raw) {
    var p = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (p.startsWith('00')) p = p.substring(2);
    if (p.startsWith('964')) return p;
    if (p.startsWith('0')) p = p.substring(1);
    return '964$p';
  }

  Future<void> _sendWhatsApp(String phone) async {
    final d = widget.data;
    final amount = (d['amount'] is num) ? (d['amount'] as num).toInt() : 0;
    final currency = (d['currency'] ?? 'IQD').toString();
    final msg = StringBuffer()
      ..writeln('🧾 وصل دفع — عصر الحداثة للتصميم والبناء')
      ..writeln('صاحب المشروع: ${d['ownerName'] ?? ''}')
      ..writeln('المبلغ المدفوع: ${moneyLabel(amount, currency)}')
      ..writeln(
          'التاريخ: ${ArDate.dateOnly(d['date'])} · ${ArDate.timeOnly(d['date'])}');
    if ('${d['note'] ?? ''}'.trim().isNotEmpty) {
      msg.writeln('وذلك عن: ${d['note']}');
    }
    final uri = Uri.parse(
        'https://wa.me/${_waNumber(phone)}?text=${Uri.encodeComponent(msg.toString())}');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذّر فتح واتساب على الجهاز.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذّر فتح واتساب على الجهاز.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final amount = (d['amount'] is num) ? (d['amount'] as num).toInt() : 0;
    final currency = (d['currency'] ?? 'IQD').toString();
    final phone = '${d['ownerPhone'] ?? ''}'.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('وصل إلكتروني'),
        actions: [
          if (widget.canManage) ...[
            IconButton(
              tooltip: 'تعديل',
              icon: const Icon(Icons.edit),
              onPressed: () => receiptDialog(
                context,
                projectId: '${d['projectId']}',
                projectCollection: widget.projectCollection,
                employeeId: '${d['employeeId']}',
                employeeName: '${d['payer'] ?? ''}',
                ownerName: '${d['ownerName'] ?? ''}',
                ownerPhone: phone,
                currency: currency,
                existing: d,
                receiptId: widget.receiptId,
              ),
            ),
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: AlertDialog(
                      content: const Text('حذف هذا الوصل؟'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('إلغاء')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('حذف',
                                style: TextStyle(color: AppColors.danger))),
                      ],
                    ),
                  ),
                );
                if (ok == true) {
                  await Db.deleteReceipt(widget.receiptId,
                      widget.projectCollection, '${d['projectId']}', amount);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            RepaintBoundary(
              key: _boundaryKey,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.green700, width: 1.4),
                ),
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ===== ترويسة احترافية مع شعار الشركة =====
                    Center(
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/logo.png',
                            height: 72,
                            errorBuilder: (context, error, stack) =>
                                const SizedBox(
                              height: 64,
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor: AppColors.green600,
                                child: Text('ع',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 24)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text('عصر الحداثة',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.green900)),
                          const Text('للتصميم والبناء',
                              style: TextStyle(color: AppColors.muted)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 7),
                            decoration: BoxDecoration(
                                color: AppColors.green700,
                                borderRadius: BorderRadius.circular(30)),
                            child: const Text('وصل دفع',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _line('المشروع', widget.projectName),
                    _line('صاحب المشروع', '${d['ownerName'] ?? ''}'),
                    if (phone.isNotEmpty) _line('الهاتف', phone),
                    const Divider(height: 22),
                    _line('الدافع', '${d['payer'] ?? ''}'),
                    _line('التاريخ',
                        '${ArDate.dateOnly(d['date'])} · ${ArDate.timeOnly(d['date'])}'),
                    const Divider(height: 22),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: AppColors.green100,
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المبلغ المدفوع',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(moneyLabel(amount, currency),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                  color: AppColors.green800)),
                        ],
                      ),
                    ),
                    if ('${d['note'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _line('وذلك عن', '${d['note']}'),
                    ],
                    const SizedBox(height: 28),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('توقيع المستلِم',
                            style: TextStyle(color: AppColors.muted)),
                        Text('ختم الشركة',
                            style: TextStyle(color: AppColors.muted)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _sharePdf,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.share, size: 18),
                    label: const Text('مشاركة / تنزيل PDF'),
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _sendWhatsApp(phone),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white),
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text('واتساب'),
                    ),
                  ),
                ],
              ],
            ),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                  'زر «واتساب» يرسل ملخص الوصل لرقم صاحب المشروع. لإرفاق الـ PDF نفسه استخدم «مشاركة» ثم اختر واتساب.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child:
                    Text(k, style: const TextStyle(color: AppColors.muted))),
            Expanded(
                child: Text(v,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
