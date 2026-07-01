import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/scheduled_reminder.dart';

/// خدمة الإشعارات المحلية (مجانية، بلا خادم):
/// • تذكير يومي بتسجيل **الدخول** عند بداية الدوام وبتسجيل **الخروج** عند نهايته
///   (حسب أوقات دوام الموظف/الشركة) — يعمل حتى والتطبيق مغلق.
/// • إشعار فوري لتأكيد تسجيل الحضور/الانصراف.
/// لا يوجد تتبّع بالخلفية. تُتجاهَل بأمان على الويب.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // معرّفات قديمة لتذكيرَي الدخول/الخروج (تُلغى إن وُجدت من إصدارات سابقة).
  static const int _checkInId = 8001;
  static const int _checkOutId = 8002;

  // نطاق معرّفات محجوز للتنبيهات المجدولة القادمة من الداشبورد.
  static const int _remBase = 8200;
  static const int _remMax = 60;

  static const _channel = AndroidNotificationChannel(
    'work_reminders',
    'تذكيرات الدوام',
    description: 'تذكير بتسجيل الدخول والخروج + تأكيد الحضور',
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
      // إن تعذّر تحديد المنطقة نكمل بالافتراضي — التذكير يبقى يومياً.
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

  /// يزامن التنبيهات اليومية المجدولة (التي يديرها المدير من الداشبورد): يلغي كل
  /// التنبيهات السابقة ثم يجدول المُفعَّلة منها — كلٌّ يتكرّر يومياً في وقته.
  Future<void> syncReminders(List<ScheduledReminder> reminders) async {
    if (kIsWeb) return;
    if (!_ready) await init();
    if (!_ready) return;
    // ألغِ النطاق المحجوز + المعرّفات القديمة قبل إعادة الجدولة.
    for (var id = _remBase; id < _remBase + _remMax; id++) {
      try {
        await _plugin.cancel(id);
      } catch (_) {}
    }
    await cancelAll();

    var i = 0;
    for (final r in reminders) {
      if (!r.enabled || i >= _remMax) continue;
      if (r.title.trim().isEmpty && r.body.trim().isEmpty) continue;
      await _scheduleDaily(
        id: _remBase + i,
        hour: r.hour,
        minute: r.min,
        title: r.title.trim().isEmpty ? 'تذكير' : r.title,
        body: r.body,
      );
      i++;
    }
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
        channelDescription: 'تذكير بتسجيل الدخول والخروج عند بداية/نهاية الدوام',
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
        // غير دقيق (inexact) — لا يتطلّب إذن المنبّهات الدقيقة، ويكفي لتذكير يومي.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // يومياً في نفس الوقت
      );
    } catch (_) {
      // نتجاهل أي فشل جدولة (قيود نظام) دون كسر التطبيق.
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

  /// يعرض إشعاراً فورياً (تأكيد تسجيل الدخول/الخروج).
  Future<void> showNow(String title, String body) async {
    if (kIsWeb) return;
    if (!_ready) await init();
    if (!_ready) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'work_reminders',
        'تذكيرات الدوام',
        channelDescription: 'إشعارات تسجيل الحضور',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      final id = 8100 + (DateTime.now().millisecondsSinceEpoch % 800);
      await _plugin.show(id, title, body, details);
    } catch (_) {}
  }

  /// يلغي تذكيرات الدوام (عند تسجيل الخروج من الحساب مثلاً).
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(_checkInId);
      await _plugin.cancel(_checkOutId);
    } catch (_) {}
  }
}
