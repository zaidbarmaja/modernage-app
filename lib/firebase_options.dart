import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// إعدادات Firebase — مشروع العميل المشترك (mohmeed-kadim).
///
/// هذه نفس قاعدة البيانات التي يستخدمها تطبيق الويب في مجلد `modage`
/// (راجع modage/js/firebase-config.js)، حتى تشترك الواجهتان في نفس Firestore.
///
/// ملاحظة: للحصول على ملفات النظام الأصلية لكل منصّة (google-services.json
/// لأندرويد و GoogleService-Info.plist لـ iOS) من الكونسول، يُفضّل تشغيل:
///   flutterfire configure --project=mohmeed-kadim
/// لكن القيم أدناه كافية لتشغيل Auth و Firestore و Storage على المنصّات.
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

  static const String _apiKey = 'AIzaSyBZYqZneGS4mUeIENHfWb9Kz6OWl2p3zsc';
  static const String _projectId = 'mohmeed-kadim';
  static const String _authDomain = 'mohmeed-kadim.firebaseapp.com';
  static const String _storageBucket = 'mohmeed-kadim.firebasestorage.app';
  static const String _messagingSenderId = '675551759018';
  static const String _appId = '1:675551759018:web:53d8cdd85d1874e48c9ed3';

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: _authDomain,
    storageBucket: _storageBucket,
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:675551759018:android:53d8cdd85d1874e48c9ed3',
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _apiKey,
    appId: '1:675551759018:ios:53d8cdd85d1874e48c9ed3',
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
    iosBundleId: 'online.modernage',
  );
}
