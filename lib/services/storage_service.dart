import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// رفع الملفات (صور العمل والمستندات) إلى Firebase Storage.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const _uuid = Uuid();

  /// يرفع صورة ويعيد رابط التحميل.
  Future<String> uploadImage(File file, {String folder = 'work_photos'}) async {
    final ext = file.path.split('.').last;
    final ref = _storage.ref('$folder/${_uuid.v4()}.$ext');
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  /// يرفع صورة من [XFile] عبر البايتات (يعمل على الويب والموبايل معاً) ويعيد
  /// رابط التحميل. مفضّل على [uploadImage] لأنه لا يعتمد على `dart:io File`.
  Future<String> uploadXFile(XFile file, {String folder = 'work_photos'}) async {
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
    final ref = _storage.ref('$folder/${_uuid.v4()}.$ext');
    final meta = SettableMetadata(contentType: file.mimeType ?? 'image/jpeg');
    final task = await ref.putData(bytes, meta);
    return task.ref.getDownloadURL();
  }

  /// يرفع عدة صور ويعيد قائمة الروابط.
  Future<List<String>> uploadImages(List<File> files,
      {String folder = 'work_photos'}) async {
    final urls = <String>[];
    for (final f in files) {
      urls.add(await uploadImage(f, folder: folder));
    }
    return urls;
  }
}
