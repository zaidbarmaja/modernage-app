import 'package:cloud_firestore/cloud_firestore.dart';

/// تنبيه يومي مجدول يديره مدير النظام من الداشبورد، ويقرأه التطبيق ليجدول إشعاراً
/// محلياً على أجهزة الموظفين (مثل: تذكير بتسجيل الدخول الساعة 10:00).
class ScheduledReminder {
  final String id;
  final String title;
  final String body;

  /// وقت التنبيه بالدقائق من منتصف الليل (10:00 صباحاً = 600).
  final int minute;
  final bool enabled;

  const ScheduledReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.minute,
    this.enabled = true,
  });

  int get hour => minute ~/ 60;
  int get min => minute % 60;

  static ScheduledReminder fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const <String, dynamic>{};
    return ScheduledReminder(
      id: doc.id,
      title: (m['title'] ?? '') as String,
      body: (m['body'] ?? '') as String,
      minute: (m['minute'] as num?)?.toInt() ?? 0,
      enabled: m['enabled'] != false, // الافتراضي مُفعّل
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'minute': minute,
        'enabled': enabled,
      };
}
