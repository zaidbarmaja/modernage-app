import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// إعدادات Firebase — مشروع المستخدم (modren-48a9c).
///
/// قيم تطبيق الويب من كونسول Firebase. لأندرويد لاحقاً يُضاف تطبيق أندرويد
/// (google-services.json) بمعرّف appId خاص به.
///
/// ملاحظة: للحصول على ملفات النظام الأصلية لكل منصّة (google-services.json
/// لأندرويد و GoogleService-Info.plist لـ iOS)، يُفضّل تشغيل الأمر:
///   flutterfire configure
/// لكن القيم أدناه كافية لتشغيل Firestore و Storage على معظم المنصّات.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        return web;
    }
  }

  static const String _apiKey = 'AIzaSyDZcliV1QFiqhCjQC4wnrR1bwsXg32kuAc';
  static const String _projectId = 'modren-48a9c';
  static const String _authDomain = 'modren-48a9c.firebaseapp.com';
  static const String _storageBucket = 'modren-48a9c.firebasestorage.app';
  static const String _messagingSenderId = '366025976353';
  static const String _appId = '1:366025976353:web:9634894369deec5b625160';
  static const String _measurementId = 'G-TGSVMLRMZQ';

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: _authDomain,
    storageBucket: _storageBucket,
    measurementId: _measurementId,
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
    iosBundleId: 'com.asralhadatha.app',
  );
}
