import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/design_project.dart';
import '../../models/work_site.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../widgets/ui.dart';
import '../../widgets/user_dropdown.dart';

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
  String? _executorUid;
  String? _executorName;
  String? _customerUid;
  double? _lat;
  double? _lng;
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
    _executorUid = s?.executorUid;
    _executorName = s?.executorName;
    _customerUid = s?.customerUid;
    _lat = s?.lat;
    _lng = s?.lng;
  }

  @override
  void dispose() {
    _owner.dispose();
    _siteName.dispose();
    _address.dispose();
    _radius.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() => _gettingLoc = true);
    try {
      final loc = await LocationService.getCurrentLocation();
      setState(() {
        _lat = loc.lat;
        _lng = loc.lng;
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
    setState(() => _busy = true);
    try {
      final data = {
        'ownerName': _owner.text.trim(),
        'siteName': _siteName.text.trim(),
        'address': _address.text.trim(),
        'lat': _lat,
        'lng': _lng,
        'radius': int.tryParse(_radius.text.trim()) ?? 100,
        'durationDays': int.tryParse(_duration.text.trim()),
        'projectId': _projectId,
        'executorUid': _executorUid,
        'executorName': _executorName,
        'customerUid': _customerUid,
      };
      if (_isEdit) {
        await _fs.updateSite(widget.existing!.id, data);
      } else {
        await _fs.addSite(WorkSite(
          id: '',
          ownerName: _owner.text.trim(),
          siteName: _siteName.text.trim(),
          address: _address.text.trim(),
          lat: _lat,
          lng: _lng,
          radius: int.tryParse(_radius.text.trim()) ?? 100,
          durationDays: int.tryParse(_duration.text.trim()),
          projectId: _projectId,
          executorUid: _executorUid,
          executorName: _executorName,
          customerUid: _customerUid,
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
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _gettingLoc ? null : _captureLocation,
                  icon: _gettingLoc
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: AppColors.cream, strokeWidth: 2.2))
                      : const Icon(Icons.my_location),
                  label: Text(_lat == null
                      ? 'تحديد إحداثيات الموقع'
                      : 'الإحداثيات: ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}'),
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
                UserDropdown(
                  role: UserRole.executionEmployee,
                  selectedUid: _executorUid,
                  label: 'إسناد إلى موظف التنفيذ',
                  icon: Icons.engineering,
                  optional: false,
                  onChanged: (u) => setState(() {
                    _executorUid = u?.uid;
                    _executorName = u?.name;
                  }),
                ),
                const SizedBox(height: 14),
                UserDropdown(
                  role: UserRole.customer,
                  selectedUid: _customerUid,
                  label: 'ربط بحساب الزبون (اختياري)',
                  icon: Icons.link,
                  onChanged: (u) => setState(() => _customerUid = u?.uid),
                ),
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
