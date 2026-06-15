import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../services/session.dart';
import '../theme.dart';
import '../utils/time_utils.dart';
import '../widgets/common.dart';
import '../widgets/project_photos.dart';
import '../widgets/project_tasks.dart';
import 'project_form.dart';

int _remainingOf(Map<String, dynamic> d) {
  final v = d['remainingDays'] ?? d['days'] ?? 0;
  final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
  return n < 0 ? 0 : n;
}

int _intOf(dynamic v) =>
    (v is num) ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

/// صفحة تفاصيل صاحب المشروع/مشروع التصميم: كل التفاصيل + القسم المالي + الملفات + تعديل.
class DesignProjectDetailScreen extends StatelessWidget {
  final EmployeeSession employee;
  final DocumentReference<Map<String, dynamic>> reference;
  /// صلاحية إدارية (تعديل المالية/الملفات/الحذف) — للوحة التحكم. الموظف يتابع
  /// المهام والحالة فقط.
  final bool canManage;
  const DesignProjectDetailScreen({
    required this.employee,
    required this.reference,
    this.canManage = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المشروع')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: reference.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const MessageView(
              icon: Icons.cloud_off,
              title: 'تعذّر تحميل التفاصيل',
              color: AppColors.danger,
            );
          }
          if (!snap.hasData) return const LoadingView();
          final doc = snap.data!;
          if (!doc.exists) {
            return const MessageView(
              icon: Icons.delete_outline,
              title: 'تم حذف هذا المشروع',
            );
          }
          final d = doc.data()!;
          final status = (d['status'] ?? 'قيد التنفيذ').toString();
          final suspended = status.contains('معلّق') || status.contains('معلق');
          final remaining = _remainingOf(d);
          final done = remaining == 0;
          final currency = (d['currency'] ?? 'IQD').toString();
          final total = _intOf(d['totalAmount']);
          final received = _intOf(d['receivedAmount'] ?? d['paidAmount']);
          final due = (total - received) < 0 ? 0 : total - received;
          final documents = (d['documents'] as List?) ?? [];
          final photos = (d['photos'] as List?) ?? [];
          final tasks = (d['tasks'] as List?) ?? [];
          final phone = (d['ownerPhone'] ?? '').toString();

          return PagePadding(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== رأس: صاحب المشروع =====
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.green800,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((d['ownerName'] ?? '—').toString(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('مشروع: ${(d['name'] ?? '').toString()}',
                          style: const TextStyle(color: AppColors.cream200)),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.phone,
                              size: 14, color: AppColors.cream300),
                          const SizedBox(width: 6),
                          Text(phone,
                              style:
                                  const TextStyle(color: AppColors.cream200)),
                        ]),
                      ],
                      if (assignedNamesLabel(d).isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.groups_outlined,
                              size: 14, color: AppColors.cream300),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text('الفريق: ${assignedNamesLabel(d)}',
                                style: const TextStyle(
                                    color: AppColors.cream200)),
                          ),
                        ]),
                      ],
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        StatusBadge(status),
                        _tag(suspended
                            ? 'الأيام مجمّدة'
                            : (done ? 'مكتمل' : '$remaining يوم متبقٍ')),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ===== المهام ونسبة الإنجاز =====
                const SectionHeader('المهام ونسبة الإنجاز'),
                _infoCard([
                  ProjectTasks(reference: reference, tasks: tasks),
                ]),
                const SizedBox(height: 18),

                // ===== حالة المشروع =====
                const SectionHeader('حالة المشروع'),
                _infoCard([
                  StatusSelector(
                    current: status,
                    onChanged: (s) => reference.update({'status': s}),
                  ),
                  if (suspended) ...[
                    const SizedBox(height: 8),
                    const Text(
                        '⏸️ المشروع معلّق — توقف احتساب الأيام المتبقية.',
                        style: TextStyle(
                            color: Color(0xFF9A6700),
                            fontWeight: FontWeight.w700)),
                  ],
                ]),
                const SizedBox(height: 18),

                // ===== القسم المالي =====
                SectionHeader('العرض المالي · ${currencyName(currency)}'),
                _infoCard([
                  _money('نوع العرض', (d['offerType'] ?? '—').toString()),
                  const Divider(),
                  _money('كامل المبلغ', moneyLabel(total, currency)),
                  _money('المستلم', moneyLabel(received, currency)),
                  const Divider(),
                  _money('الباقي', moneyLabel(due, currency), highlight: true),
                ]),
                const SizedBox(height: 18),

                // ===== التفاصيل =====
                const SectionHeader('تفاصيل المشروع'),
                _infoCard([
                  _kv('التفاصيل', (d['details'] ?? '—').toString()),
                ]),
                const SizedBox(height: 18),

                // ===== صور المشروع (يستطيع الموظف إرفاق صور) =====
                const SectionHeader('صور المشروع'),
                _infoCard([
                  ProjectPhotos(
                    reference: reference,
                    photos: photos,
                    collection: 'design_projects',
                    canManage: canManage,
                  ),
                ]),
                const SizedBox(height: 18),

                // ===== الملفات =====
                const SectionHeader('ملفات المشروع'),
                if (documents.isEmpty)
                  const Text('لا توجد ملفات مرفقة.',
                      style: TextStyle(color: AppColors.muted))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in documents)
                        Chip(
                          avatar: const Text('📄'),
                          label: Text('${(f as Map)['name'] ?? 'ملف'}'),
                          backgroundColor: AppColors.cream100,
                        ),
                    ],
                  ),
                const SizedBox(height: 22),

                // ===== أزرار الإدارة (لوحة التحكم فقط) =====
                if (canManage)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openEdit(context, doc),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('تعديل المشروع وملفاته'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => Directionality(
                              textDirection: TextDirection.rtl,
                              child: AlertDialog(
                                content:
                                    const Text('حذف هذا المشروع نهائيًا؟'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('إلغاء')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('حذف',
                                          style: TextStyle(
                                              color: AppColors.danger))),
                                ],
                              ),
                            ),
                          );
                          if (ok == true) {
                            await reference.delete();
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppColors.danger),
                        label: const Text('حذف'),
                      ),
                    ],
                  ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openEdit(
      BuildContext context, QueryDocumentSnapshotLike doc) {
    showProjectForm(context, kind: 'design', existing: doc);
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.green600,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      );

  Widget _money(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: highlight ? AppColors.green900 : AppColors.textSoft,
                  fontWeight: highlight ? FontWeight.w800 : FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  fontSize: highlight ? 18 : 15,
                  fontWeight: FontWeight.w800,
                  color: highlight ? AppColors.green700 : AppColors.text)),
        ],
      ),
    );
  }

  Widget _infoCard(List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k,
                style: const TextStyle(
                    color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 2),
            Text(v),
          ],
        ),
      );
}

/// واجهة بسيطة لتمرير بيانات المستند للنموذج (إمّا QueryDocumentSnapshot أو DocumentSnapshot).
typedef QueryDocumentSnapshotLike = DocumentSnapshot<Map<String, dynamic>>;

/// نموذج إضافة/تعديل مشروع تصميم (بالحقول المالية والملفات).
class DesignProjectForm extends StatefulWidget {
  final EmployeeSession employee;
  final DocumentReference<Map<String, dynamic>>? existingRef;
  final Map<String, dynamic>? existingData;
  final VoidCallback onDone;
  const DesignProjectForm({
    required this.employee,
    required this.onDone,
    this.existingRef,
    this.existingData,
    super.key,
  });

  @override
  State<DesignProjectForm> createState() => _DesignProjectFormState();
}

class _DesignProjectFormState extends State<DesignProjectForm> {
  late final TextEditingController _name;
  late final TextEditingController _owner;
  late final TextEditingController _phone;
  late final TextEditingController _details;
  late final TextEditingController _days;
  late final TextEditingController _offerType;
  late final TextEditingController _total;
  late final TextEditingController _received;

  String _currency = 'IQD';
  final List<UploadFile> _newDocs = [];
  List<dynamic> _existingDocs = [];
  bool _busy = false;

  bool get isEdit => widget.existingRef != null;

  @override
  void initState() {
    super.initState();
    final d = widget.existingData ?? {};
    _name = TextEditingController(text: d['name']?.toString() ?? '');
    _owner = TextEditingController(text: d['ownerName']?.toString() ?? '');
    _phone = TextEditingController(text: d['ownerPhone']?.toString() ?? '');
    _details = TextEditingController(text: d['details']?.toString() ?? '');
    _days = TextEditingController(text: isEdit ? '${_remainingOf(d)}' : '');
    _offerType =
        TextEditingController(text: d['offerType']?.toString() ?? '');
    final total = _intOf(d['totalAmount']);
    final received = _intOf(d['receivedAmount'] ?? d['paidAmount']);
    _total = TextEditingController(text: total == 0 ? '' : '$total');
    _received = TextEditingController(text: received == 0 ? '' : '$received');
    _currency = (d['currency'] ?? 'IQD').toString() == 'USD' ? 'USD' : 'IQD';
    _existingDocs = (d['documents'] as List?) ?? [];
  }

  @override
  void dispose() {
    _name.dispose();
    _owner.dispose();
    _phone.dispose();
    _details.dispose();
    _days.dispose();
    _offerType.dispose();
    _total.dispose();
    _received.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final res = await FilePicker.platform
        .pickFiles(allowMultiple: true, withData: true);
    if (res == null) return;
    for (final f in res.files) {
      if (f.bytes != null) _newDocs.add(UploadFile(f.name, f.bytes!));
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final owner = _owner.text.trim();
    final daysVal = int.tryParse(_days.text.trim());
    if (name.isEmpty || owner.isEmpty || daysVal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('الرجاء تعبئة اسم المشروع وصاحبه وعدد الأيام')));
      return;
    }
    setState(() => _busy = true);
    try {
      final uploaded =
          await Db.uploadFiles(_newDocs, 'documents', 'design_projects');
      final documents = [..._existingDocs, ...uploaded];
      final data = {
        'name': name,
        'ownerName': owner,
        'ownerPhone': _phone.text.trim(),
        'details': _details.text.trim(),
        'remainingDays': daysVal,
        'offerType': _offerType.text.trim(),
        'currency': _currency,
        'totalAmount': int.tryParse(_total.text.trim()) ?? 0,
        'receivedAmount': int.tryParse(_received.text.trim()) ?? 0,
        'documents': documents,
      };
      if (isEdit) {
        await widget.existingRef!.update(data);
      } else {
        await Db.designProjects.add({
          ...data,
          'days': daysVal,
          'status': daysVal == 0 ? 'منجز' : 'قيد التنفيذ',
          'tasks': <Map<String, dynamic>>[],
          'employeeId': widget.employee.id,
          'employeeName': widget.employee.name,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      widget.onDone();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذّر الحفظ. حاول مجددًا.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
      margin: isEdit ? null : const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEdit ? 'تعديل مشروع التصميم' : 'إضافة مشروع تصميم جديد',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            _field('اسم المشروع', _name),
            _field('اسم صاحب المشروع', _owner),
            _field('رقم هاتف صاحب المشروع', _phone,
                keyboard: TextInputType.phone),
            _field('تفاصيل المشروع', _details, maxLines: 3),
            _field('عدد الأيام', _days, keyboard: TextInputType.number),
            _field('نوع العرض', _offerType),
            const Text('العملة', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('دينار عراقي'),
                  selected: _currency == 'IQD',
                  onSelected: (_) => setState(() => _currency = 'IQD'),
                ),
                ChoiceChip(
                  label: const Text('دولار'),
                  selected: _currency == 'USD',
                  onSelected: (_) => setState(() => _currency = 'USD'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _field('كامل المبلغ', _total,
                        keyboard: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(
                    child: _field('المستلم', _received,
                        keyboard: TextInputType.number)),
              ],
            ),
            _filesSection(),
            const SizedBox(height: 6),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'حفظ التعديلات' : 'حفظ المشروع'),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                    onPressed: widget.onDone, child: const Text('إلغاء')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filesSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ملفات المشروع', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in _existingDocs)
                Chip(
                  label: Text('${(f as Map)['name'] ?? 'ملف'}'),
                  onDeleted: () => setState(() => _existingDocs.remove(f)),
                  backgroundColor: AppColors.cream100,
                ),
              for (final f in _newDocs)
                Chip(
                  avatar: const Icon(Icons.upload_file, size: 16),
                  label: Text(f.name),
                  onDeleted: () => setState(() => _newDocs.remove(f)),
                  backgroundColor: AppColors.green100,
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('إضافة ملف'),
                onPressed: _pick,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {int maxLines = 1, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          TextField(controller: c, maxLines: maxLines, keyboardType: keyboard),
        ],
      ),
    );
  }
}
