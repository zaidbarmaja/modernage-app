import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import 'app_user.dart';

/// تنبيه يومي مجدول يديره مدير النظام من الداشبورد، ويقرأه التطبيق ليجدول إشعاراً
/// محلياً على أجهزة الفئة المستهدفة (مثل: تذكير بتسجيل الدخول الساعة 10:00).
class ScheduledReminder {
  final String id;
  final String title;
  final String body;

  /// وقت التنبيه بالدقائق من منتصف الليل (10:00 صباحاً = 600).
  final int minute;
  final bool enabled;

  /// الفئة المستهدفة: all | execution | design | pools | customers.
  final String audience;

  const ScheduledReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.minute,
    this.enabled = true,
    this.audience = 'all',
  });

  int get hour => minute ~/ 60;
  int get min => minute % 60;

  /// هل يستهدف هذا التنبيه المستخدم [u]؟
  bool matchesUser(AppUser u) {
    switch (audience) {
      case 'execution':
        return u.role == UserRole.executionEmployee;
      case 'design':
        return u.role == UserRole.designEmployee;
      case 'pools':
        return u.role == UserRole.executionEmployee && u.workCategory.isPools;
      case 'customers':
        return u.role == UserRole.customer;
      case 'all':
      default:
        return true;
    }
  }

  static ScheduledReminder fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const <String, dynamic>{};
    return ScheduledReminder(
      id: doc.id,
      title: (m['title'] ?? '') as String,
      body: (m['body'] ?? '') as String,
      minute: (m['minute'] as num?)?.toInt() ?? 0,
      enabled: m['enabled'] != false, // الافتراضي مُفعّل
      audience: (m['audience'] ?? 'all') as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'minute': minute,
        'enabled': enabled,
        'audience': audience,
      };
}
