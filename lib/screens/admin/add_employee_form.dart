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

  UserRole _role = UserRole.designEmployee;
  Department _department = Department.civil;
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 16, minute: 0);
  bool _busy = false;
  bool _obscure = true;

  static const _roles = [
    UserRole.designEmployee,
    UserRole.executionEmployee,
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
      _department =
          e.department == Department.none ? Department.civil : e.department;
      _start = TimeOfDay(hour: e.workStartMin ~/ 60, minute: e.workStartMin % 60);
      _end = TimeOfDay(hour: e.workEndMin ~/ 60, minute: e.workEndMin % 60);
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
    final dept = _needsSchedule ? _department : Department.none;
    final startMin = _needsSchedule ? _toMin(_start) : 8 * 60;
    final endMin = _needsSchedule ? _toMin(_end) : 16 * 60;
    if (_needsSchedule && endMin <= startMin) {
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
          'department': dept.id,
          'workStartMin': startMin,
          'workEndMin': endMin,
          'loginNames':
              _auth.loginKeys(_name.text.trim(), _phone.text.trim()),
        });
      } else {
        await _auth.createEmployeeAccount(
          name: _name.text.trim(),
          username: _name.text.trim(),
          password: _password.text,
          role: _role,
          department: dept,
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
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور (لدخول الموظف)',
                      helperText: 'يدخل الموظف باسمه أعلاه وكلمة المرور هذه',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'كلمة المرور 6 أحرف على الأقل'
                        : null,
                  ),
                const SizedBox(height: 14),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  isExpanded: true,
                  dropdownColor: AppColors.surfaceAlt,
                  decoration: const InputDecoration(
                    labelText: 'الوظيفة',
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                  items: _roles
                      .map((r) =>
                          DropdownMenuItem(value: r, child: Text(r.labelAr)))
                      .toList(),
                  onChanged: (v) => setState(() => _role = v ?? _role),
                ),
                if (_needsSchedule) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<Department>(
                    initialValue: _department,
                    isExpanded: true,
                    dropdownColor: AppColors.surfaceAlt,
                    decoration: const InputDecoration(
                      labelText: 'القسم (تصنيف)',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: const [Department.civil, Department.architectural]
                        .map((d) =>
                            DropdownMenuItem(value: d, child: Text(d.labelAr)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _department = v ?? _department),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _timeButton('بداية الدوام', _start,
                            (t) => setState(() => _start = t)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _timeButton('نهاية الدوام', _end,
                            (t) => setState(() => _end = t)),
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

  Widget _timeButton(
      String label, TimeOfDay value, ValueChanged<TimeOfDay> onPick) {
    return InkWell(
      onTap: () async {
        final picked =
            await showTimePicker(context: context, initialTime: value);
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule),
        ),
        child: Text(value.format(context),
            style: const TextStyle(color: AppColors.cream)),
      ),
    );
  }
}
