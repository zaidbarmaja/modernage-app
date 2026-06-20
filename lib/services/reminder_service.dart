import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// خدمة التذكيرات المحلية المجدولة (مجانية، بلا خادم) — تُذكّر الموظف يومياً
/// بتسجيل الدخول عند بداية الدوام وبتسجيل الخروج عند نهايته. تعمل على أندرويد/iOS
/// (حتى والتطبيق مغلق)، ولا تعمل على الويب (تُتجاهَل بأمان).
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // معرّفات ثابتة للإشعارين كي تُستبدل لا تتكرّر.
  static const int _checkInId = 8001;
  static const int _checkOutId = 8002;

  static const _channel = AndroidNotificationChannel(
    'work_reminders',
    'تذكيرات الدوام',
    description: 'تذكير بتسجيل الدخول والخروج عند بداية/نهاية الدوام',
    importance: Importance.high,
  );

  /// تهيئة الإضافة + المنطقة الزمنية + طلب الإذن. تُستدعى مرّة عند الإقلاع.
  Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      tzdata.initializeTimeZones();
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      // إن تعذّر تحديد المنطقة نكمل بالافتراضي (UTC) — التذكير يبقى يومياً.
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    try {
      await _plugin.initialize(settings);
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_channel);
      await android?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// يجدول تذكيرَي الدخول/الخروج اليوميين على وقت دوام الشركة.
  /// [workStartMin]/[workEndMin] دقائق من منتصف الليل.
  Future<void> scheduleWorkReminders({
    required int workStartMin,
    required int workEndMin,
  }) async {
    if (kIsWeb) return;
    if (!_ready) await init();
    if (!_ready) return;
    await _scheduleDaily(
      id: _checkInId,
      hour: workStartMin ~/ 60,
      minute: workStartMin % 60,
      title: 'تذكير بتسجيل الدخول',
      body: 'حان وقت الدوام — لا تنسَ تسجيل بصمة الدخول من موقع الشركة.',
    );
    await _scheduleDaily(
      id: _checkOutId,
      hour: workEndMin ~/ 60,
      minute: workEndMin % 60,
      title: 'تذكير بتسجيل الخروج',
      body: 'انتهى الدوام — لا تنسَ تسجيل بصمة الخروج.',
    );
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    final scheduled = _nextInstanceOf(hour, minute);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'work_reminders',
        'تذكيرات الدوام',
        channelDescription:
            'تذكير بتسجيل الدخول والخروج عند بداية/نهاية الدوام',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // يومياً في نفس الوقت
      );
    } catch (_) {
      // نتجاهل أي فشل جدولة (مثلاً قيود نظام) دون كسر التطبيق.
    }
  }

  /// أقرب وقت قادم (اليوم إن لم يَمضِ، وإلا الغد) بالمنطقة المحلية.
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// يلغي كل التذكيرات (عند الخروج مثلاً).
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(_checkInId);
      await _plugin.cancel(_checkOutId);
    } catch (_) {}
  }
}
