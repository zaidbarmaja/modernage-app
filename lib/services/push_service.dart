import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'firestore_service.dart';
import 'reminder_service.dart';

/// معالج رسائل الخلفية (مطلوب على مستوى أعلى). رسائل نوع notification يعرضها
/// نظام التشغيل تلقائياً في شريط الإشعارات حتى والتطبيق مغلق، فلا حاجة لعمل شيء.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// خدمة الإشعارات الفورية (Firebase Cloud Messaging): تصل الهاتف والتطبيق مغلق
/// مع صوت — مثل تطبيقات التواصل. تسجّل رمز الجهاز في ملف المستخدم كي ترسله
/// Cloud Function عند إنشاء أي إشعار.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _fm = FirebaseMessaging.instance;
  bool _wired = false;
  String? _uid;

  /// يُسجّل جهاز المستخدم لاستقبال الإشعارات. آمن للاستدعاء المتكرّر.
  Future<void> register(String uid) async {
    if (kIsWeb || uid.isEmpty) return;
    _uid = uid;
    try {
      await _fm.requestPermission(alert: true, badge: true, sound: true);
      // iOS: إظهار الإشعار حتى والتطبيق مفتوح.
      await _fm.setForegroundNotificationPresentationOptions(
          alert: true, badge: true, sound: true);

      final token = await _fm.getToken();
      if (token != null) {
        await FirestoreService().saveFcmToken(uid, token);
      }

      if (!_wired) {
        _wired = true;
        // تحديث الرمز إن غيّره النظام.
        _fm.onTokenRefresh.listen((t) {
          final u = _uid;
          if (u != null) FirestoreService().saveFcmToken(u, t).catchError((_) {});
        });
        // أثناء فتح التطبيق: نعرض الإشعار محلياً على أندرويد (النظام لا يعرضه
        // تلقائياً في المقدّمة). iOS يعرضه بنفسه عبر الإعداد أعلاه.
        FirebaseMessaging.onMessage.listen(_onForeground);
      }
    } catch (_) {
      // نتجاهل أي فشل (بلا إنترنت/إذن مرفوض) دون كسر الجلسة.
    }
  }

  void _onForeground(RemoteMessage m) {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final n = m.notification;
    if (n == null) return;
    ReminderService.instance.showNow(n.title ?? 'إشعار', n.body ?? '');
  }
}
