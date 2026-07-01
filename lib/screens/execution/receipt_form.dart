import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_notification.dart';
import '../../models/app_user.dart';
import '../../models/receipt.dart';
import '../../models/work_site.dart';
import '../../services/firebase_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/account_customer_picker.dart';
import '../../widgets/ui.dart';

/// نموذج إصدار وصل إلكتروني (T-3.4): المبلغ + المستلِم + الوصف + صورة + التاريخ.
/// [site] اختياري: عند تمريره يُربط الوصل بالموقع (موظف التنفيذ)، وعند غيابه
/// يكون وصلاً مستقلاً يُصدره المدير باختيار الزبون من الحسابات فقط.
class ReceiptForm extends StatefulWidget {
  final WorkSite? site;
  final AppUser executor; // مُصدِر الوصل (موظف التنفيذ أو المدير)
  const ReceiptForm({super.key, this.site, required this.executor});

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
  final _recipient = TextEditingController();
  DateTime _date = DateTime.now();
  XFile? _image;
  Uint8List? _imageBytes; // للمعاينة (يعمل على الويب والموبايل)
  bool _busy = false;
  bool _isExpense = false; // false = وصل قبض، true = وصل صرف
  String? _customerName; // الزبون المختار من قاعدة البيانات (إجباري)

  @override
  void initState() {
    super.initState();
    // يُملأ مبدئيًا باسم صاحب الموقع إن كان زبونًا في القائمة، ويبقى الاختيار إجباريًا.
    final owner = widget.site?.ownerName.trim() ?? '';
    _customerName = owner.isEmpty ? null : owner;
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    _recipient.dispose();
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
    final customer = _customerName?.trim() ?? '';
    if (customer.isEmpty) {
      showSnack(context, 'اختر الزبون من القائمة (إجباري).', error: true);
      return;
    }
    setState(() => _busy = true);
    var imageUrl = '';
    try {
      final site = widget.site;
      if (_image != null) {
        imageUrl = await _storage.uploadXFile(_image!,
            folder: 'receipts/${site?.id ?? 'admin'}');
      }
      final amount = num.parse(_amount.text.trim());
      // صاحب المشروع: اسم الموقع إن وُجد، وإلا اسم الزبون المختار (وصل مستقل).
      final ownerName = (site?.ownerName.trim().isNotEmpty ?? false)
          ? site!.ownerName
          : customer;
      final recipient = _recipient.text.trim();

      // كلا النوعين (قبض/صرف) يُحفظ في وصولات التطبيق ليظهر في صفحة الوصولات
      // كاملةً، ويُنسخ إلى حسابات الزبائن المشتركة كـ«دفع إلكتروني».
      final ref = await _fs.addReceipt(Receipt(
        id: '',
        siteId: site?.id ?? '',
        siteName: site?.siteName ?? '',
        ownerName: ownerName,
        projectId: site?.projectId,
        customerUid: site?.customerUid,
        amount: amount,
        expense: _isExpense,
        description: _desc.text.trim(),
        recipient: recipient,
        imageUrl: imageUrl,
        createdByUid: widget.executor.uid,
        createdByName: widget.executor.name,
        date: _date,
      ));
      final customerUid = site?.customerUid ?? '';
      if (customerUid.isNotEmpty) {
        await _fs.addNotification(AppNotification(
          id: '',
          type: 'receipt',
          title: _isExpense
              ? 'وصل صرف: ${Fmt.money(amount)}'
              : 'وصل قبض: ${Fmt.money(amount)}',
          body:
              '${widget.executor.name} ${_isExpense ? 'سجّل صرفاً' : 'أصدر وصل قبض'} '
              'بقيمة ${Fmt.money(amount)} لموقع $ownerName',
          fromUid: widget.executor.uid,
          fromName: widget.executor.name,
          toUid: customerUid,
          relatedId: site?.id,
        ));
      }
      // مرآة في الحسابات المشتركة (لا نُفشل الوصل إن تعذّر).
      try {
        await Db.addElectronicPayment(
          customerName: customer,
          amount: amount,
          expense: _isExpense,
          description: _desc.text.trim(),
          date: _date,
          byName: widget.executor.name,
          imageUrl: imageUrl,
          receiptId: ref.id,
        );
      } catch (_) {}
      if (mounted) {
        showSnack(context,
            _isExpense ? 'تم تسجيل وصل الصرف ✓' : 'تم إصدار وصل القبض ✓');
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
      appBar: AppBar(
          title: Text(_isExpense ? 'وصل صرف جديد' : 'وصل قبض جديد')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                        value: false,
                        label: Text('وصل قبض'),
                        icon: Icon(Icons.south_west)),
                    ButtonSegment(
                        value: true,
                        label: Text('وصل صرف'),
                        icon: Icon(Icons.north_east)),
                  ],
                  selected: {_isExpense},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _isExpense = s.first),
                ),
                const SizedBox(height: 14),
                if (widget.site != null) ...[
                  Text('الموقع: ${widget.site!.ownerName}',
                      style: const TextStyle(color: AppColors.creamDim)),
                  const SizedBox(height: 14),
                ],
                // اختيار الزبون من قاعدة البيانات (إجباري).
                AccountCustomerPicker(
                  selectedName: _customerName,
                  label: 'الزبون (إجباري — من قائمة الحسابات)',
                  onSelected: (name) => setState(() => _customerName = name),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: _isExpense ? 'المبلغ المصروف' : 'المبلغ المقبوض',
                    prefixIcon: const Icon(Icons.payments),
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
                TextFormField(
                  controller: _recipient,
                  decoration: const InputDecoration(
                    labelText: 'المستلِم (اسم من استلم/سُلِّم له المبلغ)',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
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
                  label: Text(_busy
                      ? 'جارٍ الحفظ...'
                      : (_isExpense ? 'تسجيل وصل الصرف' : 'إصدار وصل القبض')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
