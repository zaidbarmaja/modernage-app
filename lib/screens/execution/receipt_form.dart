import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_notification.dart';
import '../../models/app_user.dart';
import '../../models/receipt.dart';
import '../../models/work_site.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/ui.dart';

/// نموذج إصدار وصل إلكتروني (T-3.4): المبلغ + الوصف + صورة مرفقة + التاريخ.
class ReceiptForm extends StatefulWidget {
  final WorkSite site;
  final AppUser executor;
  const ReceiptForm({super.key, required this.site, required this.executor});

  @override
  State<ReceiptForm> createState() => _ReceiptFormState();
}

class _ReceiptFormState extends State<ReceiptForm> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();
  final _storage = StorageService();
  final _picker = ImagePicker();

  final _amount = TextEditingController();
  final _desc = TextEditingController();
  DateTime _date = DateTime.now();
  XFile? _image;
  Uint8List? _imageBytes; // للمعاينة (يعمل على الويب والموبايل)
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final f = await _picker.pickImage(source: source, imageQuality: 70);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (mounted) {
        setState(() {
          _image = f;
          _imageBytes = bytes;
        });
      }
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر اختيار الصورة.', error: true);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    var imageUrl = '';
    try {
      if (_image != null) {
        imageUrl = await _storage.uploadXFile(_image!,
            folder: 'receipts/${widget.site.id}');
      }
      final amount = num.parse(_amount.text.trim());
      await _fs.addReceipt(Receipt(
        id: '',
        siteId: widget.site.id,
        siteName: widget.site.siteName,
        ownerName: widget.site.ownerName,
        projectId: widget.site.projectId,
        customerUid: widget.site.customerUid,
        amount: amount,
        description: _desc.text.trim(),
        imageUrl: imageUrl,
        createdByUid: widget.executor.uid,
        createdByName: widget.executor.name,
        date: _date,
      ));
      // إشعار بوصل جديد موجّه للزبون المعني (والإدارة ترى كل الإشعارات) — T-4.5.
      // لا نُنشئ إشعاراً بلا مستلِم إن لم يكن الموقع مربوطاً بزبون.
      final customerUid = widget.site.customerUid ?? '';
      if (customerUid.isNotEmpty) {
        await _fs.addNotification(AppNotification(
          id: '',
          type: 'receipt',
          title: 'وصل جديد: ${Fmt.money(amount)}',
          body:
              '${widget.executor.name} أصدر وصلاً بقيمة ${Fmt.money(amount)} لموقع ${widget.site.ownerName}',
          fromUid: widget.executor.uid,
          fromName: widget.executor.name,
          toUid: customerUid,
          relatedId: widget.site.id,
        ));
      }
      if (mounted) {
        showSnack(context, 'تم إصدار الوصل ✓');
        Navigator.pop(context);
      }
    } catch (_) {
      // فشلت الكتابة بعد رفع الصورة: احذفها كي لا تبقى يتيمة في Storage.
      if (imageUrl.isNotEmpty) await _storage.deleteByUrl(imageUrl);
      if (mounted) showSnack(context, 'تعذّر إصدار الوصل.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('وصل إلكتروني جديد')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('الموقع: ${widget.site.ownerName}',
                    style: const TextStyle(color: AppColors.creamDim)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المدفوع',
                    prefixIcon: Icon(Icons.payments),
                    suffixText: 'د.ع',
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'أدخل المبلغ';
                    final n = num.tryParse(t);
                    if (n == null) return 'مبلغ غير صالح';
                    if (n <= 0) return 'يجب أن يكون المبلغ أكبر من صفر';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _desc,
                  maxLines: 3,
                  maxLength: 240,
                  decoration: const InputDecoration(
                    labelText: 'وصف الدفعة',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'اكتب وصف الدفعة'
                      : null,
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text('تاريخ الدفع: ${Fmt.date(_date)}'),
                ),
                const SizedBox(height: 18),
                const Text('صورة الوصل (اختياري)',
                    style: TextStyle(
                        color: AppColors.cream, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('كاميرا'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _busy ? null : () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('المعرض'),
                      ),
                    ),
                  ],
                ),
                if (_imageBytes != null) ...[
                  const SizedBox(height: 12),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _imageBytes!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _image = null;
                            _imageBytes = null;
                          }),
                          child: Container(
                            decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 26),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: AppColors.cream, strokeWidth: 2.2))
                      : const Icon(Icons.save),
                  label: Text(_busy ? 'جارٍ الحفظ...' : 'إصدار الوصل'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
