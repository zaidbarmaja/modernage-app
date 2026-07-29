// ===============================================================
//  عصر الحداثة — ملف الإشعارات الموحّد (كل شيء عن الإشعارات هنا)
//
//  لا يوجد أي مكان آخر في التطبيق يرسل إشعاراً أو يجدوله. أي إشعار يظهر على
//  هاتف المستخدم مصدره سطر واحد من هذا الملف.
//
//  ─────────────────── فهرس كل الإشعارات في النظام ───────────────────
//
//  (١) إشعارات تصل الهاتف والتطبيق مغلق (Push):
//      تُكتَب أولاً في مجموعة `notifications` بقاعدة البيانات، ثم تلتقطها
//      الدالة السحابية `pushOnNotification` (functions/index.js) وترسلها
//      للأجهزة عبر FCM خلال ثانية أو ثانيتين — تلقائياً وبلا تدخّل.
//
//      • تقرير تنفيذ جديد   → Notifications.newReport()   يناديها report_form.dart
//                             المستلِم: زبون الموقع فقط.
//      • وصل قبض/صرف       → Notifications.newReceipt()  يناديها receipt_form.dart
//                             المستلِم: زبون الموقع فقط.
//      • إشعار عام للجميع  → Notifications.broadcast()   يناديها admin_notifications.dart
//                             المستلِم: كل مستخدمي النظام (إشعار لكل واحد).
//      • دخول موقع عمل     → Notifications.siteCheckIn() (جاهزة للاستخدام)
//                             المستلِم: من تحدّده.
//
//      ملاحظة: لوحة التحكم (الويب) ترسل بنفس الطريقة تماماً من
//      DASHBORD/js/data.js ← broadcastNotification()، وتدعم التوجيه حسب الفئة.
//
//  (٢) إشعارات محلية على الجهاز (بلا إنترنت وبلا سيرفر):
//      • تذكيرات الدوام اليومية → Notifications.syncDailyReminders()
//        يديرها المدير من الداشبورد (مجموعة scheduled_reminders)، والتطبيق
//        يجدولها على الجهاز عند الدخول حسب فئة الموظف.
//      • إشعار فوري/تأكيد       → Notifications.showNow()
//        يُستخدم أيضاً لعرض إشعار Push عندما يكون التطبيق مفتوحاً (أندرويد).
//
//  (٣) البنية التحتية:
//      • Notifications.init()           تهيئة القناة والأذونات — عند الإقلاع.
//      • Notifications.registerDevice() تسجيل رمز الجهاز — عند الدخول.
//      • Notifications.cancelAll()      إلغاء التذكيرات — عند الخروج.
//
//  (٤) القراءة والعرض داخل التطبيق:
//      • Notifications.allStream()      كل الإشعارات (شاشة الإدارة).
//      • Notifications.streamFor(uid)   إشعارات مستخدم واحد (زبون/موظف).
//      • Notifications.markRead(id)     تعليم إشعار كمقروء.
//
//  قناة أندرويد المستخدمة في كل ما سبق: `work_reminders` (أهمية عالية + صوت).
//  أي تغيير في اسم القناة يجب أن يطابق AndroidManifest.xml و functions/index.js.
// ===============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/constants.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/scheduled_reminder.dart';

/// معالج رسائل الخلفية (FCM) — يجب أن يكون دالة عليا خارج أي كلاس.
/// رسائل نوع notification يعرضها نظام التشغيل تلقائياً في شريط الإشعارات
/// حتى والتطبيق مغلق، فلا نحتاج عمل شيء هنا.
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(RemoteMessage message) async {}

/// المصدر الوحيد لكل إشعارات التطبيق — إرسالاً وجدولةً وعرضاً.
class Notifications {
  Notifications._();
  static final Notifications _i = Notifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _fm = FirebaseMessaging.instance;
  final _db = FirebaseFirestore.instance;

  bool _ready = false;
  bool _pushWired = false;
  String? _pushUid;
  String? _fcmToken; // آخر رمز جهاز مسجّل (لإزالته عند التغيّر)
  String? _lastReminderSig; // بصمة آخر مجموعة تنبيهات جُدولت (تفادي إعادة الجدولة)

  // ---- نطاقات معرّفات منفصلة كي لا يمسح إشعار إشعاراً آخر ----
  static const int _legacyInId = 8001; // تذكيرات قديمة (تُلغى إن وُجدت)
  static const int _legacyOutId = 8002;
  static const int _remBase = 8200; // التنبيهات المجدولة: 8200..8259
  static const int _remMax = 60;
  static const int _nowBase = 9000; // الإشعارات الفورية: 9000..9799 (منفصل)

  static const _channel = AndroidNotificationChannel(
    'work_reminders',
    'تذكيرات الدوام والإشعارات',
    description: 'تذكيرات الدوام + تأكيد الحضور + الإشعارات الفورية',
    importance: Importance.high,
  );

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'work_reminders',
      'تذكيرات الدوام والإشعارات',
      channelDescription: 'تذكيرات الدوام والإشعارات',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  CollectionReference<Map<String, dynamic>> get _notifs =>
      _db.collection(FsCollections.notifications);

  /* ==================================================================
   *  (١) إرسال الإشعارات — كل ما يخرج من التطبيق إلى أجهزة المستخدمين
   * ================================================================== */

  /// إشعار «تقرير تنفيذ جديد» → يصل زبون الموقع كإشعار على هاتفه.
  /// المصدر: شاشة إضافة تقرير التنفيذ (report_form.dart).
  static Future<void> newReport({
    required String customerUid,
    required String siteOwnerName,
    required String executorUid,
    required String executorName,
    String? siteId,
  }) {
    if (customerUid.isEmpty) return Future.value(); // بلا مستلِم = لا إشعار
    return _i._send(AppNotification(
      id: '',
      type: 'report',
      title: 'تقرير تنفيذ جديد',
      body: '$executorName أضاف تقريراً لموقع $siteOwnerName',
      fromUid: executorUid,
      fromName: executorName,
      toUid: customerUid,
      relatedId: siteId,
    ));
  }

  /// إشعار «وصل قبض/صرف» → يصل زبون الموقع كإشعار على هاتفه.
  /// المصدر: شاشة إصدار الوصل (receipt_form.dart).
  static Future<void> newReceipt({
    required String customerUid,
    required String siteOwnerName,
    required String executorUid,
    required String executorName,
    required String amountText,
    required bool expense,
    String? siteId,
  }) {
    if (customerUid.isEmpty) return Future.value();
    return _i._send(AppNotification(
      id: '',
      type: 'receipt',
      title: expense ? 'وصل صرف: $amountText' : 'وصل قبض: $amountText',
      body: '$executorName ${expense ? 'سجّل صرفاً' : 'أصدر وصل قبض'} '
          'بقيمة $amountText لموقع $siteOwnerName',
      fromUid: executorUid,
      fromName: executorName,
      toUid: customerUid,
      relatedId: siteId,
    ));
  }

  /// إشعار «دخول موقع عمل» → يصل المستلِم المحدّد.
  /// جاهز للاستخدام عند ربط تسجيل الدخول للمواقع بالإشعارات.
  static Future<void> siteCheckIn({
    required String toUid,
    required String employeeUid,
    required String employeeName,
    required String siteName,
    String? siteId,
    double? lat,
    double? lng,
  }) {
    if (toUid.isEmpty) return Future.value();
    return _i._send(AppNotification(
      id: '',
      type: 'site_checkin',
      title: 'دخول موقع عمل',
      body: '$employeeName دخل موقع $siteName',
      fromUid: employeeUid,
      fromName: employeeName,
      toUid: toUid,
      relatedId: siteId,
      lat: lat,
      lng: lng,
    ));
  }

  /// إشعار عام للجميع: يُنشأ إشعار موجّه لكل مستخدم (toUid = uid) دفعةً واحدة،
  /// فيظهر لكلٍّ في تبويب إشعاراته **ويصله Push على هاتفه**.
  /// يدعم حتى ~٥٠٠ مستخدم في الدفعة الواحدة. يُرجع عدد من وصلهم الإشعار.
  /// المصدر: شاشة إشعارات الإدارة (admin_notifications.dart).
  static Future<int> broadcast({
    required String title,
    required String body,
    required String fromUid,
    required String fromName,
  }) async {
    final usersSnap = await _i._db.collection(FsCollections.users).get();
    final batch = _i._db.batch();
    for (final doc in usersSnap.docs) {
      batch.set(
        _i._notifs.doc(),
        AppNotification(
          id: '',
          type: 'broadcast',
          title: title,
          body: body,
          fromUid: fromUid,
          fromName: fromName,
          toUid: doc.id,
        ).toMap(),
      );
    }
    await batch.commit();
    return usersSnap.docs.length;
  }

  /// الكتابة الفعلية في مجموعة `notifications`. هذه هي اللحظة التي تنطلق فيها
  /// الدالة السحابية وترسل الإشعار للهاتف.
  Future<void> _send(AppNotification n) => _notifs.add(n.toMap());

  /* ==================================================================
   *  (٢) القراءة والعرض داخل التطبيق
   * ================================================================== */

  /// كل الإشعارات (شاشة الإدارة — ترى كل شيء).
  static Stream<List<AppNotification>> allStream() =>
      _i._notifs.snapshots().map(_map);

  /// إشعارات مستخدم واحد فقط (الزبون/الموظف يرى ما يخصّه).
  static Stream<List<AppNotification>> streamFor(String uid) =>
      _i._notifs.where('toUid', isEqualTo: uid).snapshots().map(_map);

  /// تعليم إشعار كمقروء.
  static Future<void> markRead(String id) =>
      _i._notifs.doc(id).update({'read': true});

  static List<AppNotification> _map(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map(AppNotification.fromDoc).toList();
    list.sort((a, b) => (b.createdAt ?? DateTime(2000))
        .compareTo(a.createdAt ?? DateTime(2000)));
    return list;
  }

  /* ==================================================================
   *  (٣) التهيئة — تُستدعى مرّة واحدة عند إقلاع التطبيق (main.dart)
   * ================================================================== */

  /// تهيئة الإضافة + المنطقة الزمنية + قناة الإشعارات + طلب الإذن.
  static Future<void> init() => _i._init();

  Future<void> _init() async {
    if (kIsWeb || _ready) return;
    _initTimeZone();
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

  void _initTimeZone() {
    try {
      tzdata.initializeTimeZones();
      FlutterTimezone.getLocalTimezone().then((name) {
        try {
          tz.setLocalLocation(tz.getLocation(name));
        } catch (_) {
          _fallbackZone();
        }
      }).catchError((_) {
        _fallbackZone();
      });
    } catch (_) {
      _fallbackZone();
    }
  }

  /// عند تعذّر تحديد المنطقة الزمنية نستخدم بغداد بدل UTC كي لا تنحرف الأوقات.
  void _fallbackZone() {
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Baghdad'));
    } catch (_) {}
  }

  /* ==================================================================
   *  (٤) الإشعارات المحلية — تذكيرات الدوام اليومية
   * ================================================================== */

  /// يقرأ تنبيهات الداشبورد ويجدول ما يطابق فئة [user] فقط على جهازه.
  /// لا يُنشئ التطبيق أي تنبيه من تلقاء نفسه — كلها من لوحة التحكم.
  /// يتخطّى إعادة الجدولة إن لم تتغيّر المجموعة (تقليل التكلفة).
  static Future<void> syncDailyReminders(AppUser user) =>
      _i._syncRemindersFor(user);

  Future<void> _syncRemindersFor(AppUser user) async {
    if (kIsWeb) return;
    try {
      final all =
          await _readScheduledReminders().timeout(const Duration(seconds: 10));
      await _syncReminders(all.where((r) => r.matchesUser(user)).toList());
    } catch (_) {
      // نتجاهل أي فشل (بلا إنترنت مثلاً) دون كسر الجلسة.
    }
  }

  /// قراءة لمرّة واحدة لتنبيهات الداشبورد (مجموعة scheduled_reminders).
  Future<List<ScheduledReminder>> _readScheduledReminders() async {
    final snap = await _db.collection(FsCollections.scheduledReminders).get();
    final list = <ScheduledReminder>[];
    for (final d in snap.docs) {
      try {
        list.add(ScheduledReminder.fromDoc(d));
      } catch (_) {}
    }
    return list;
  }

  Future<void> _syncReminders(List<ScheduledReminder> reminders) async {
    if (!_ready) await _init();
    if (!_ready) return;

    // بصمة المجموعة المفعّلة — إن لم تتغيّر منذ آخر جدولة، لا نعيد الجدولة.
    final active = reminders.where((r) => r.enabled).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final sig = active
        .map((r) => '${r.id}|${r.minute}|${r.enabled}|${r.title}|${r.body}')
        .join('~');
    if (sig == _lastReminderSig) return;
    _lastReminderSig = sig;

    await _cancelAll();
    var i = 0;
    for (final r in active) {
      if (i >= _remMax) break;
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
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // يومياً بنفس الوقت
      );
    } catch (_) {}
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// يلغي كل التنبيهات المجدولة (نطاق الداشبورد + المعرّفات القديمة).
  /// تُستدعى عند تسجيل الخروج كي لا تبقى تذكيرات المستخدم السابق على الجهاز.
  static Future<void> cancelAll() => _i._cancelAll();

  Future<void> _cancelAll() async {
    if (kIsWeb) return;
    _lastReminderSig = null;
    try {
      for (var id = _remBase; id < _remBase + _remMax; id++) {
        await _plugin.cancel(id);
      }
      await _plugin.cancel(_legacyInId);
      await _plugin.cancel(_legacyOutId);
    } catch (_) {}
  }

  /* ==================================================================
   *  (٥) إشعار فوري على الجهاز (تأكيد إجراء / عرض Push في المقدّمة)
   * ================================================================== */

  static Future<void> showNow(String title, String body) =>
      _i._showNow(title, body);

  Future<void> _showNow(String title, String body) async {
    if (kIsWeb) return;
    if (!_ready) await _init();
    if (!_ready) return;
    try {
      // نطاق منفصل (9000+) كي لا يمسح إشعار فوري تذكيراً مجدولاً.
      final id = _nowBase + (DateTime.now().millisecondsSinceEpoch % 800);
      await _plugin.show(id, title, body, _details);
    } catch (_) {}
  }

  /* ==================================================================
   *  (٦) تسجيل الجهاز لاستقبال الإشعارات الفورية (FCM)
   * ================================================================== */

  /// يسجّل رمز جهاز المستخدم في `users/{uid}.fcmTokens` — بدونه لا يصل أي Push.
  /// آمن للاستدعاء المتكرّر. يُنادى من role_router.dart عند الدخول.
  static Future<void> registerDevice(String uid) => _i._registerPush(uid);

  Future<void> _registerPush(String uid) async {
    if (kIsWeb || uid.isEmpty) return;
    _pushUid = uid;
    try {
      await _fm.requestPermission(alert: true, badge: true, sound: true);
      await _fm.setForegroundNotificationPresentationOptions(
          alert: true, badge: true, sound: true);

      final token = await _fm.getToken();
      if (token != null && token != _fcmToken) {
        _fcmToken = token;
        await _saveToken(uid, token);
      }

      if (!_pushWired) {
        _pushWired = true;
        _fm.onTokenRefresh.listen((t) async {
          final u = _pushUid;
          if (u == null || t == _fcmToken) return;
          try {
            // نزيل الرمز القديم ونضيف الجديد كي لا تتراكم رموز ميّتة.
            final old = _fcmToken;
            _fcmToken = t;
            if (old != null) await _removeToken(u, old);
            await _saveToken(u, t);
          } catch (_) {}
        });
        FirebaseMessaging.onMessage.listen(_onForeground);
      }
    } catch (_) {}
  }

  /// يحفظ رمز الجهاز في ملف المستخدم — الدالة السحابية تقرأ من هنا.
  Future<void> _saveToken(String uid, String token) =>
      _db.collection(FsCollections.users).doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));

  /// يزيل رمز جهاز قديماً/مبطلاً (كي لا تتراكم رموز ميّتة).
  Future<void> _removeToken(String uid, String token) =>
      _db.collection(FsCollections.users).doc(uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });

  void _onForeground(RemoteMessage m) {
    // أندرويد فقط: النظام لا يعرض الإشعار في المقدّمة تلقائياً. iOS يعرضه بنفسه.
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final n = m.notification;
    if (n == null) return;
    _showNow(n.title ?? 'إشعار', n.body ?? '');
  }
}
