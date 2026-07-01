import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/design_project.dart';
import '../../models/work_site.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../widgets/account_customer_picker.dart';
import '../../widgets/ui.dart';

/// نموذج إضافة/تعديل موقع عمل للتنفيذ (الإدارة حسب التصميم).
class AddSiteForm extends StatefulWidget {
  final WorkSite? existing;
  const AddSiteForm({super.key, this.existing});

  @override
  State<AddSiteForm> createState() => _AddSiteFormState();
}

class _AddSiteFormState extends State<AddSiteForm> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();

  late final TextEditingController _owner;
  late final TextEditingController _siteName;
  late final TextEditingController _address;
  late final TextEditingController _radius;
  late final TextEditingController _duration;

  String? _projectId;
  final List<String> _executorUids = []; // يدعم إسناد الموقع لأكثر من منفّذ
  final List<String> _executorNames = [];
  String? _customerUid;
  WorkCategory _category = WorkCategory.general;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  bool _busy = false;
  bool _gettingLoc = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _owner = TextEditingController(text: s?.ownerName ?? '');
    _siteName = TextEditingController(text: s?.siteName ?? '');
    _address = TextEditingController(text: s?.address ?? '');
    _radius = TextEditingController(text: '${s?.radius ?? 100}');
    _duration = TextEditingController(
        text: s?.durationDays == null ? '' : '${s!.durationDays}');
    _projectId = s?.projectId;
    if (s != null) {
      _executorUids.addAll(s.executorUids);
      _executorNames.addAll(s.executorNames);
    }
    _customerUid = s?.customerUid;
    _category = s?.category ?? WorkCategory.general;
    _lat = TextEditingController(text: s?.lat?.toString() ?? '');
    _lng = TextEditingController(text: s?.lng?.toString() ?? '');
  }

  @override
  void dispose() {
    _owner.dispose();
    _siteName.dispose();
    _address.dispose();
    _radius.dispose();
    _duration.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() => _gettingLoc = true);
    try {
      final loc = await LocationService.getCurrentLocation();
      setState(() {
        _lat.text = loc.lat.toString();
        _lng.text = loc.lng.toString();
        if (_address.text.trim().isEmpty && loc.address.isNotEmpty) {
          _address.text = loc.address;
        }
      });
      if (mounted) showSnack(context, 'تم تحديد موقع العمل ✓');
    } on LocationException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _gettingLoc = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_executorUids.isEmpty) {
      showSnack(context, 'اختر منفّذاً واحداً على الأقل.', error: true);
      return;
    }
    // الإحداثيات اختيارية؛ إن أُدخلت فيجب أن تكون كاملة وضمن المدى الصحيح.
    final latText = _lat.text.trim();
    final lngText = _lng.text.trim();
    double? lat;
    double? lng;
    if (latText.isNotEmpty || lngText.isNotEmpty) {
      lat = double.tryParse(latText);
      lng = double.tryParse(lngText);
      if (lat == null || lng == null) {
        showSnack(context, 'أدخل خطّي العرض والطول معاً بصيغة رقمية صحيحة.',
            error: true);
        return;
      }
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
        showSnack(context, 'الإحداثيات خارج النطاق (العرض ±90، الطول ±180).',
            error: true);
        return;
      }
    }
    setState(() => _busy = true);
    try {
      // المنفّذ الأساسي (الأول) يُحفظ مفرداً أيضاً للتوافق مع العروض القديمة.
      final firstUid = _executorUids.first;
      final firstName = _executorNames.isNotEmpty ? _executorNames.first : '';
      final data = {
        'ownerName': _owner.text.trim(),
        'siteName': _siteName.text.trim(),
        'address': _address.text.trim(),
        'lat': lat,
        'lng': lng,
        'radius': int.tryParse(_radius.text.trim()) ?? 100,
        'durationDays': int.tryParse(_duration.text.trim()),
        'projectId': _projectId,
        'executorUid': firstUid,
        'executorName': firstName,
        'executorUids': _executorUids,
        'executorNames': _executorNames,
        'customerUid': _customerUid,
        'category': _category.id,
      };
      if (_isEdit) {
        await _fs.updateSite(widget.existing!.id, data);
      } else {
        await _fs.addSite(WorkSite(
          id: '',
          ownerName: _owner.text.trim(),
          siteName: _siteName.text.trim(),
          address: _address.text.trim(),
          lat: lat,
          lng: lng,
          radius: int.tryParse(_radius.text.trim()) ?? 100,
          durationDays: int.tryParse(_duration.text.trim()),
          projectId: _projectId,
          executorUid: firstUid,
          executorName: firstName,
          executorUids: _executorUids,
          executorNames: _executorNames,
          customerUid: _customerUid,
          category: _category,
        ));
      }
      if (mounted) {
        showSnack(context, _isEdit ? 'تم تحديث الموقع ✓' : 'تمت إضافة الموقع ✓');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر حفظ الموقع.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// منتقي إسناد متعدّد: يُمكن اختيار أكثر من موظف تنفيذ لنفس الموقع.
  Widget _executorsPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.engineering, size: 18, color: AppColors.oliveBright),
            SizedBox(width: 8),
            Expanded(
              child: Text('إسناد لموظفي التنفيذ (يمكن اختيار أكثر من واحد)',
                  style: TextStyle(
                      color: AppColors.cream, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<AppUser>>(
          stream: _fs.usersByRole(UserRole.executionEmployee),
          builder: (context, snap) {
            final emps = snap.data ?? const <AppUser>[];
            if (emps.isEmpty) {
              return const Text('لا يوجد موظفو تنفيذ بعد.',
                  style: TextStyle(color: AppColors.creamDim));
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: emps.map((e) {
                final label = e.name.isEmpty ? e.phone : e.name;
                final selected = _executorUids.contains(e.uid);
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  selectedColor: AppColors.oliveDark,
                  checkmarkColor: AppColors.cream,
                  onSelected: (v) => setState(() {
                    if (v) {
                      if (!_executorUids.contains(e.uid)) {
                        _executorUids.add(e.uid);
                        _executorNames.add(label);
                      }
                    } else {
                      final i = _executorUids.indexOf(e.uid);
                      if (i >= 0) {
                        _executorUids.removeAt(i);
                        if (i < _executorNames.length) {
                          _executorNames.removeAt(i);
                        }
                      }
                    }
                  }),
                );
              }).toList(),
            );
          },
        ),
        if (_executorUids.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('المختارون (${_executorUids.length}): ${_executorNames.join('، ')}',
              style:
                  const TextStyle(color: AppColors.oliveBright, fontSize: 12)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل موقع عمل' : 'موقع عمل جديد')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // اختيار من مشاريع التصميم لتعبئة البيانات تلقائياً.
                StreamBuilder<List<DesignProject>>(
                  stream: _fs.allProjects(),
                  builder: (context, snapshot) {
                    final projects = snapshot.data ?? [];
                    final value = projects.any((p) => p.id == _projectId)
                        ? _projectId
                        : null;
                    return DropdownButtonFormField<String?>(
                      initialValue: value,
                      isExpanded: true,
                      dropdownColor: AppColors.surfaceAlt,
                      decoration: const InputDecoration(
                        labelText: 'مرتبط بمشروع تصميم (اختياري)',
                        prefixIcon: Icon(Icons.architecture),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('بدون ربط')),
                        ...projects.map((p) => DropdownMenuItem<String?>(
                              value: p.id,
                              child: Text('${p.ownerName} — ${p.offerType}'),
                            )),
                      ],
                      onChanged: (id) {
                        setState(() {
                          _projectId = id;
                          if (id != null) {
                            final p =
                                projects.firstWhere((e) => e.id == id);
                            if (_owner.text.trim().isEmpty) {
                              _owner.text = p.ownerName;
                            }
                            _customerUid ??= p.customerUid;
                          }
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<WorkCategory>(
                  initialValue: _category,
                  isExpanded: true,
                  dropdownColor: AppColors.surfaceAlt,
                  decoration: const InputDecoration(
                    labelText: 'قسم التنفيذ',
                    prefixIcon: Icon(Icons.category_outlined),
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
                const SizedBox(height: 14),
                AccountCustomerPicker(
                  selectedName:
                      _owner.text.trim().isEmpty ? null : _owner.text.trim(),
                  onSelected: (name) => setState(() => _owner.text = name),
                ),
                const SizedBox(height: 14),
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
                const SizedBox(height: 14),
                TextFormField(
                  controller: _siteName,
                  decoration: const InputDecoration(
                    labelText: 'اسم/عنوان الموقع',
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'أدخل اسم الموقع'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _address,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'وصف العنوان',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.my_location,
                        size: 18, color: AppColors.oliveBright),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('إحداثيات الموقع (اختياري)',
                          style: TextStyle(
                              color: AppColors.cream,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _lat,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'خط العرض (Lat)',
                          prefixIcon: Icon(Icons.swap_vert),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _lng,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'خط الطول (Lng)',
                          prefixIcon: Icon(Icons.swap_horiz),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _gettingLoc ? null : _captureLocation,
                  icon: _gettingLoc
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: AppColors.cream, strokeWidth: 2.2))
                      : const Icon(Icons.gps_fixed),
                  label: const Text('تعبئة الإحداثيات من موقعي الحالي (GPS)'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _radius,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'نطاق السماح بالحضور (متر)',
                    helperText:
                        'يُسمح للمنفّذ بتسجيل الدخول داخل هذا النطاق فقط',
                    helperMaxLines: 2,
                    prefixIcon: Icon(Icons.adjust),
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 10) {
                      return 'أدخل نطاقاً صحيحاً (10 متر فأكثر)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'مدة التنفيذ المتوقعة (أيام)',
                    prefixIcon: Icon(Icons.timelapse),
                  ),
                ),
                const SizedBox(height: 14),
                _executorsPicker(),
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
                  label: Text(_isEdit ? 'حفظ التعديلات' : 'إضافة الموقع'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
