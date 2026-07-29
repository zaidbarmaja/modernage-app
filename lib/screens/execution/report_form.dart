import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/execution_report.dart';
import '../../models/work_site.dart';
import '../../services/firestore_service.dart';
import '../../services/notifications.dart';
import '../../services/storage_service.dart';
import '../../widgets/ui.dart';

/// نموذج تقرير تنفيذ يومي: مستندات/ملاحظات، صور، أعمال قادمة، مدة التنفيذ.
class ReportForm extends StatefulWidget {
  final WorkSite site;
  final AppUser executor;
  const ReportForm({super.key, required this.site, required this.executor});

  @override
  State<ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<ReportForm> {
  final _formKey = GlobalKey<FormState>();
  final _fs = FirestoreService();
  final _storage = StorageService();
  final _picker = ImagePicker();

  final _planned = TextEditingController();
  final _duration = TextEditingController();
  final List<XFile> _picked = [];
  final List<Uint8List> _bytes = []; // للمعاينة (يعمل على الويب والموبايل)
  bool _busy = false;

  @override
  void dispose() {
    _planned.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _add(XFile f) async {
    final bytes = await f.readAsBytes();
    if (!mounted) return;
    setState(() {
      _picked.add(f);
      _bytes.add(bytes);
    });
  }

  Future<void> _pickImages() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 70);
      for (final f in files) {
        await _add(f);
      }
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر اختيار الصور.', error: true);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final file =
          await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
      if (file != null) await _add(file);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذّر فتح الكاميرا.', error: true);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final urls = <String>[];
      for (final x in _picked) {
        urls.add(await _storage.uploadXFile(x,
            folder: 'reports/${widget.site.id}'));
      }
      await _fs.addReport(ExecutionReport(
        id: '',
        siteId: widget.site.id,
        siteName: widget.site.siteName,
        ownerName: widget.site.ownerName,
        executorUid: widget.executor.uid,
        executorName: widget.executor.name,
        date: DateTime.now(),
        documentsNotes: '',
        plannedNextDays: _planned.text.trim(),
        durationDays: int.tryParse(_duration.text.trim()),
        photoUrls: urls,
        customerUid: widget.site.customerUid,
      ));
      // إشعار بتقرير جديد موجّه لزبون الموقع (والإدارة ترى الكل) — T-4.5.
      // نصّ الإشعار ومستلِمه محدّدان في services/notifications.dart.
      await Notifications.newReport(
        customerUid: widget.site.customerUid ?? '',
        siteOwnerName: widget.site.ownerName,
        executorUid: widget.executor.uid,
        executorName: widget.executor.name,
        siteId: widget.site.id,
      );
      if (mounted) {
        showSnack(context, 'تم حفظ التقرير ✓');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showSnack(context, 'تعذّر حفظ التقرير: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقرير يومي جديد')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _planned,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'ماذا ستنفّذ في الأيام القادمة؟',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.upcoming_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'مدة تنفيذ هذا العمل (أيام)',
                    prefixIcon: Icon(Icons.timelapse),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('الصور اليومية للعمل',
                    style: TextStyle(
                        color: AppColors.cream, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _takePhoto,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('كاميرا'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _pickImages,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('المعرض'),
                      ),
                    ),
                  ],
                ),
                if (_picked.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _picked.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _bytes[i],
                              width: 92,
                              height: 92,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: 0,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _picked.removeAt(i);
                                _bytes.removeAt(i);
                              }),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                  label: Text(_busy ? 'جارٍ الرفع...' : 'حفظ التقرير'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
