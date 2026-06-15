import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../theme.dart';

/// قسم صور المشروع: عرض الصور المرفقة + إرفاق صور جديدة (متاح للموظف والمدير).
class ProjectPhotos extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> reference;
  final List<dynamic> photos;
  final String collection; // اسم المجموعة لمسار التخزين
  final bool canManage; // حذف الصور (للمدير)
  const ProjectPhotos({
    required this.reference,
    required this.photos,
    required this.collection,
    this.canManage = false,
    super.key,
  });

  @override
  State<ProjectPhotos> createState() => _ProjectPhotosState();
}

class _ProjectPhotosState extends State<ProjectPhotos> {
  bool _busy = false;

  Future<void> _pickAndUpload() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.image,
    );
    if (res == null) return;
    final files = <UploadFile>[];
    for (final f in res.files) {
      if (f.bytes != null) files.add(UploadFile(f.name, f.bytes!));
    }
    if (files.isEmpty) return;
    setState(() => _busy = true);
    try {
      final uploaded =
          await Db.uploadFiles(files, 'photos', widget.collection);
      await widget.reference.update({'photos': FieldValue.arrayUnion(uploaded)});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذّر رفع الصور. حاول مجددًا.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(dynamic item) async {
    try {
      await widget.reference.update({
        'photos': FieldValue.arrayRemove([item])
      });
    } catch (_) {}
  }

  void _view(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('تعذّر عرض الصورة'),
                  )),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photos.isEmpty)
          const Text('لا توجد صور بعد. أرفِق صور العمل بالضغط على «إرفاق صورة».',
              style: TextStyle(color: AppColors.muted, fontSize: 13))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in photos)
                if (p is Map && '${p['url'] ?? ''}'.isNotEmpty)
                  _thumb('${p['url']}', p),
            ],
          ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _pickAndUpload,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_a_photo_outlined, size: 18),
            label: const Text('إرفاق صورة'),
          ),
        ),
      ],
    );
  }

  Widget _thumb(String url, dynamic item) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _view(url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              url,
              width: 90,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                width: 90,
                height: 90,
                color: AppColors.cream100,
                child: const Icon(Icons.broken_image_outlined,
                    color: AppColors.muted),
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: 90,
                  height: 90,
                  color: AppColors.cream100,
                  alignment: Alignment.center,
                  child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                );
              },
            ),
          ),
        ),
        if (widget.canManage)
          Positioned(
            top: 2,
            left: 2,
            child: InkWell(
              onTap: () => _remove(item),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
