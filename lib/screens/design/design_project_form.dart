import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/design_project.dart';
import '../../services/firestore_service.dart';
import '../../widgets/account_customer_picker.dart';
import '../../widgets/ui.dart';
import '../../widgets/user_dropdown.dart';

/// نموذج إضافة/تعديل مشروع تصميم:
/// - من شاشة المصمم: يُمرَّر [designer] فيكون المصمم ثابتاً.
/// - من لوحة الإدارة: يُترك [designer] فارغاً فيظهر منتقي المصمم.
/// في الحالتين يمكن ربط المشروع بحساب زبون.
class DesignProjectForm extends StatefulWidget {
  final AppUser? designer;
  final DesignProject? existing;

  const DesignProjectForm({super.key, this.designer, this.existing});

  @override
  State<DesignProjectForm> createState() => _DesignProjectFormState();
}

class _DesignProjectFormState extends State<DesignProjectForm> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();

  late final TextEditingController _owner;
  late final TextEditingController _details;
  late final TextEditingController _days;
  late final TextEditingController _next;
  String? _designerUid;
  String? _designerName;
  String? _customerUid;
  String _status = kProjectStatuses.first;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  /// وضع الإدارة: لا مصمم ثابت ← يظهر منتقي المصمم.
  bool get _pickDesigner => widget.designer == null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _owner = TextEditingController(text: p?.ownerName ?? '');
    _details = TextEditingController(text: p?.details ?? '');
    final rem = p?.remainingDays;
    _days =
        TextEditingController(text: (rem != null && rem >= 0) ? '$rem' : '');
    _next = TextEditingController(text: p?.nextPresentation ?? '');
    _designerUid = p?.designerUid ?? widget.designer?.uid;
    _designerName = p?.designerName ?? widget.designer?.name;
    _customerUid = p?.customerUid;
    _status = p?.status ?? kProjectStatuses.first;
  }

  @override
  void dispose() {
    _owner.dispose();
    _details.dispose();
    _days.dispose();
    _next.dispose();
    super.dispose();
  }

  /// يحوّل عدد الأيام المتبقية إلى تاريخ تسليم (اليوم + الأيام).
  DateTime? _deliveryFromDays() {
    final d = int.tryParse(_days.text.trim());
    if (d == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: d));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final delivery = _deliveryFromDays();
    try {
      if (_isEdit) {
        await _fs.updateProject(widget.existing!.id, {
          'ownerName': _owner.text.trim(),
          'details': _details.text.trim(),
          'customerUid': _customerUid,
          'status': _status,
          'nextPresentation': _next.text.trim(),
          'deliveryDate':
              delivery == null ? null : Timestamp.fromDate(delivery),
        });
      } else {
        await _fs.addProject(DesignProject(
          id: '',
          ownerName: _owner.text.trim(),
          details: _details.text.trim(),
          offerType: '',
          status: _status,
          nextPresentation: _next.text.trim(),
          deliveryDate: delivery,
          designerUid: _designerUid ?? '',
          designerName: _designerName ?? '',
          customerUid: _customerUid,
        ));
      }
      if (mounted) {
        showSnack(
            context, _isEdit ? 'تم تحديث المشروع ✓' : 'تمت إضافة المشروع ✓');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر الحفظ.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(_isEdit ? 'تعديل المشروع' : 'مشروع تصميم جديد')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_pickDesigner) ...[
                  UserDropdown(
                    role: UserRole.designEmployee,
                    selectedUid: _designerUid,
                    label: 'إسناد إلى مصمم',
                    icon: Icons.architecture,
                    optional: false,
                    onChanged: (u) => setState(() {
                      _designerUid = u?.uid;
                      _designerName = u?.name;
                    }),
                  ),
                  const SizedBox(height: 16),
                ],
                AccountCustomerPicker(
                  selectedName:
                      _owner.text.trim().isEmpty ? null : _owner.text.trim(),
                  onSelected: (name) => setState(() => _owner.text = name),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _owner,
                  decoration: const InputDecoration(
                    labelText: 'اسم صاحب المشروع',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'أدخل اسم صاحب المشروع'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _details,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل/متطلبات المشروع',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'أدخل تفاصيل المشروع'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _next,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'العرض الموالي للزبون (اختياري)',
                    hintText: 'موعد/تفاصيل التسليم القادم — يظهر للزبون',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.upcoming_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'عدد الأيام المتبقية (اختياري)',
                    prefixIcon: Icon(Icons.event_available),
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null; // اختياري
                    final n = int.tryParse(t);
                    if (n == null || n < 0) return 'أدخل عدد أيام صحيح';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  isExpanded: true,
                  dropdownColor: AppColors.surfaceAlt,
                  decoration: const InputDecoration(
                    labelText: 'حالة المشروع',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: kProjectStatuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: AppColors.cream, strokeWidth: 2.2))
                      : const Icon(Icons.save),
                  label: Text(_isEdit ? 'حفظ التعديلات' : 'إضافة المشروع'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
