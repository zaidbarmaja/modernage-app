import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/ui.dart';

/// نموذج إضافة/تعديل موظف من لوحة الإدارة:
/// اسم + اسم دخول + كلمة مرور + دور + قسم + **وقت دوام مخصّص يحدّده المدير**.
class AddEmployeeForm extends StatefulWidget {
  final AppUser? existing;
  const AddEmployeeForm({super.key, this.existing});

  @override
  State<AddEmployeeForm> createState() => _AddEmployeeFormState();
}

class _AddEmployeeFormState extends State<AddEmployeeForm> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();
  final _auth = AuthService();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _password;

  UserRole _role = UserRole.executionEmployee;
  Department _department = Department.none; // محفوظ من التعديل (لا يُختار الآن)
  WorkCategory _category = WorkCategory.general; // قسم التنفيذ (عام/مسابح)
  // أوقات الدوام اختيارية (null = غير محدّدة) — المهمة #4.
  TimeOfDay? _start;
  TimeOfDay? _end;
  bool _busy = false;
  bool _obscure = true;

  // المسميات الوظيفية الثلاثة حصراً (المهمة #4): تنفيذ / تصميم / محاسب.
  static const _roles = [
    UserRole.executionEmployee,
    UserRole.designEmployee,
    UserRole.accounting,
  ];

  bool get _isEdit => widget.existing != null;

  /// الدوار التي تحتاج جدول دوام (بصمة).
  bool get _needsSchedule =>
      _role == UserRole.designEmployee || _role == UserRole.executionEmployee;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _password = TextEditingController();
    if (e != null) {
      _role = e.role;
      _department = e.department;
      _category = e.workCategory;
      _start = e.workStartMin != null
          ? TimeOfDay(
              hour: e.workStartMin! ~/ 60, minute: e.workStartMin! % 60)
          : null;
      _end = e.workEndMin != null
          ? TimeOfDay(hour: e.workEndMin! ~/ 60, minute: e.workEndMin! % 60)
          : null;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  int _toMin(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // أوقات الدوام اختيارية: تُحفظ فقط إن حدّدها المدير، وإلا تبقى null.
    final int? startMin =
        _needsSchedule && _start != null ? _toMin(_start!) : null;
    final int? endMin =
        _needsSchedule && _end != null ? _toMin(_end!) : null;
    if (startMin != null && endMin != null && endMin <= startMin) {
      showSnack(context, 'وقت نهاية الدوام يجب أن يكون بعد البداية.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      if (_isEdit) {
        await _fs.updateUser(widget.existing!.uid, {
          'name': _name.text.trim(),
          'phone': _phone.text.trim(),
          'role': _role.id,
          'department': _department.id,
          'workCategory':
              (_role == UserRole.executionEmployee ? _category : WorkCategory.general)
                  .id,
          // نكتب أوقات الدوام فقط للأدوار التي تحتاج جدولاً، وإلا نُبقي القيم
          // المخزّنة كما هي بدل محوها عند التبديل لدور بلا دوام.
          if (_needsSchedule) 'workStartMin': startMin,
          if (_needsSchedule) 'workEndMin': endMin,
          'loginNames':
              _auth.loginKeys(_name.text.trim(), _phone.text.trim()),
        });
      } else {
        await _auth.createEmployeeAccount(
          name: _name.text.trim(),
          username: _name.text.trim(),
          password: _password.text,
          role: _role,
          department: _department,
          workCategory: _role == UserRole.executionEmployee
              ? _category
              : WorkCategory.general,
          workStartMin: startMin,
          workEndMin: endMin,
          phone: _phone.text.trim(),
        );
      }
      if (mounted) {
        showSnack(context, _isEdit ? 'تم تحديث الموظف ✓' : 'تمت إضافة الموظف ✓');
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر حفظ الموظف.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل موظف' : 'إضافة موظف')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'اسم الموظف',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'أدخل اسم الموظف' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف (اختياري — للدخول البديل)',
                    helperText: 'يستطيع الموظف الدخول باسمه أو برقم هاتفه',
                    helperMaxLines: 2,
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                if (!_isEdit)
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'رمز الدخول — 4 أرقام',
                      helperText: 'يدخل الموظف باسمه أعلاه وهذا الرمز',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.length != 4 || int.tryParse(t) == null) {
                        return 'رمز الدخول 4 أرقام';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 14),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  isExpanded: true,
                  dropdownColor: AppColors.surfaceAlt,
                  decoration: const InputDecoration(
                    labelText: 'القسم / الوظيفة',
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                  // عند التعديل نضمّ الدور الحالي حتى لو لم يكن من الأدوار الثلاثة
                  // (مثلاً زبون/أدمن) لتفادي تعطّل القائمة بقيمة غير موجودة.
                  items: (<UserRole>{..._roles, if (_isEdit) _role}.toList())
                      .map((r) =>
                          DropdownMenuItem(value: r, child: Text(r.labelAr)))
                      .toList(),
                  onChanged: (v) => setState(() => _role = v ?? _role),
                ),
                if (_role == UserRole.executionEmployee) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<WorkCategory>(
                    initialValue: _category,
                    isExpanded: true,
                    dropdownColor: AppColors.surfaceAlt,
                    decoration: const InputDecoration(
                      labelText: 'قسم التنفيذ',
                      prefixIcon: Icon(Icons.account_tree_outlined),
                    ),
                    items: WorkCategory.values
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Row(
                                children: [
                                  Icon(c.icon,
                                      size: 18, color: AppColors.oliveBright),
                                  const SizedBox(width: 8),
                                  Text(c.labelAr),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _category = v ?? _category),
                  ),
                ],
                if (_needsSchedule) ...[
                  const SizedBox(height: 18),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('أوقات الدوام (اختياري)',
                        style: TextStyle(
                            color: AppColors.cream,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                        'اتركها فارغة الآن إن لم تُحدَّد بعد (يُعتمد دوام افتراضي).',
                        style: TextStyle(
                            color: AppColors.creamDim, fontSize: 12)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _timeButton('بداية الدوام', _start,
                            (t) => setState(() => _start = t),
                            () => setState(() => _start = null)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _timeButton('نهاية الدوام', _end,
                            (t) => setState(() => _end = t),
                            () => setState(() => _end = null)),
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
                  label: Text(_isEdit ? 'حفظ التعديلات' : 'إضافة الموظف'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeButton(String label, TimeOfDay? value,
      ValueChanged<TimeOfDay> onPick, VoidCallback onClear) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
            context: context,
            initialTime: value ?? const TimeOfDay(hour: 8, minute: 0));
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule),
          suffixIcon: value == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'مسح',
                  onPressed: onClear,
                ),
        ),
        child: Text(
          value == null ? 'غير محدّد' : value.format(context),
          style: TextStyle(
              color: value == null ? AppColors.creamDim : AppColors.cream),
        ),
      ),
    );
  }
}
