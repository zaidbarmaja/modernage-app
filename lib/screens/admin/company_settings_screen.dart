import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/company_settings.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../widgets/ui.dart';

/// إعدادات الشركة (يحدّدها المدير): موقع البصمة المعتمد + نطاقه، ووقت الدوام
/// الموحّد لكل الموظفين (يُستخدم للبصمة وللتذكير بالدخول/الخروج).
class CompanySettingsTab extends StatefulWidget {
  const CompanySettingsTab({super.key});

  @override
  State<CompanySettingsTab> createState() => _CompanySettingsTabState();
}

class _CompanySettingsTabState extends State<CompanySettingsTab> {
  final _fs = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _radius = TextEditingController(text: '150');
  double? _lat;
  double? _lng;
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 16, minute: 0);
  bool _loaded = false;
  bool _busy = false;
  bool _gettingLoc = false;

  @override
  void dispose() {
    _name.dispose();
    _radius.dispose();
    super.dispose();
  }

  void _fill(CompanySettings s) {
    if (_loaded) return;
    _loaded = true;
    _name.text = s.name;
    _radius.text = '${s.radius}';
    _lat = s.lat;
    _lng = s.lng;
    _start = TimeOfDay(hour: s.workStartMin ~/ 60, minute: s.workStartMin % 60);
    _end = TimeOfDay(hour: s.workEndMin ~/ 60, minute: s.workEndMin % 60);
  }

  Future<void> _captureLocation() async {
    setState(() => _gettingLoc = true);
    try {
      final loc = await LocationService.getCurrentLocation();
      setState(() {
        _lat = loc.lat;
        _lng = loc.lng;
      });
      if (mounted) showSnack(context, 'تم تحديد موقع الشركة ✓');
    } on LocationException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _gettingLoc = false);
    }
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
        context: context, initialTime: start ? _start : _end);
    if (picked != null) {
      setState(() {
        if (start) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _fs.setCompanySettings(CompanySettings(
        name: _name.text.trim(),
        lat: _lat,
        lng: _lng,
        radius: int.tryParse(_radius.text.trim()) ?? 150,
        workStartMin: _start.hour * 60 + _start.minute,
        workEndMin: _end.hour * 60 + _end.minute,
      ));
      if (mounted) {
        showSnack(context, 'تم حفظ إعدادات الشركة ✓');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'تعذّر الحفظ: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CompanySettings>(
      stream: _fs.companySettings(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          _fill(snap.data ?? const CompanySettings());
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PageHeader(
                      title: 'إعدادات الشركة',
                      subtitle: 'موقع البصمة المعتمد + وقت الدوام الموحّد',
                      icon: Icons.apartment,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'اسم الشركة (اختياري)',
                        prefixIcon: Icon(Icons.business),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SectionCard(
                      title: 'موقع الشركة (للبصمة)',
                      icon: Icons.location_on,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _lat == null
                                ? 'لم يُحدَّد موقع الشركة بعد — يُسجّل الموظفون البصمة من داخل نطاقه حصراً.'
                                : 'الموقع: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                            style: const TextStyle(
                                color: AppColors.creamDim, height: 1.5),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _gettingLoc ? null : _captureLocation,
                            icon: _gettingLoc
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: AppColors.cream,
                                        strokeWidth: 2.2))
                                : const Icon(Icons.my_location),
                            label: Text(_lat == null
                                ? 'تحديد موقع الشركة (من هنا)'
                                : 'إعادة تحديد الموقع'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _radius,
                            keyboardType: TextInputType.number,
                            textDirection: TextDirection.ltr,
                            decoration: const InputDecoration(
                              labelText: 'نطاق السماح بالبصمة (متر)',
                              prefixIcon: Icon(Icons.adjust),
                            ),
                            validator: (v) {
                              final n = int.tryParse((v ?? '').trim());
                              if (n == null || n < 20) {
                                return 'أدخل نطاقاً صحيحاً (20 متر فأكثر)';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SectionCard(
                      title: 'وقت الدوام الموحّد',
                      icon: Icons.schedule,
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickTime(true),
                              icon: const Icon(Icons.login, size: 18),
                              label: Text('الدخول: ${_fmt(_start)}'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickTime(false),
                              icon: const Icon(Icons.logout, size: 18),
                              label: Text('الخروج: ${_fmt(_end)}'),
                            ),
                          ),
                        ],
                      ),
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
                      label: const Text('حفظ الإعدادات'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
  }
}
