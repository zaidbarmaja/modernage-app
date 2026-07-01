import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/app_user.dart';
import '../models/scheduled_reminder.dart';
import '../services/firestore_service.dart';
import '../services/reminder_service.dart';

/// غلاف جلسة المستخدم: يهيّئ الإشعارات، ويجدول **تذكيرات الدوام** اليومية لموظفي
/// التصميم/التنفيذ (تذكير بالدخول عند بداية الدوام وبالخروج عند نهايته) حسب أوقات
/// دوامهم — تعمل حتى والتطبيق مغلق، بلا أي تتبّع للموقع في الخلفية.
///
/// تسجيل الحضور نفسه **يدوي** (زر + بصمة إصبع)، ويُطلب إذن الموقع «أثناء الاستخدام»
/// لحظة الضغط فقط.
class LocationGate extends StatefulWidget {
  final Widget child;
  final AppUser? user;
  const LocationGate({super.key, required this.child, this.user});

  @override
  State<LocationGate> createState() => _LocationGateState();
}

class _LocationGateState extends State<LocationGate> {
  @override
  void initState() {
    super.initState();
    // طلب إذن الإشعارات (idempotent) + جدولة تذكيرات الدوام.
    ReminderService.instance.init();
    _scheduleWorkReminders();
  }

  /// يجدول التنبيهات اليومية لموظفي التصميم/التنفيذ: يقرأ التنبيهات التي يديرها
  /// المدير من الداشبورد؛ وإن لم يضبط المدير أيّاً بعد، يستخدم افتراضياً تذكيراً
  /// بالدخول عند بداية الدوام وبالخروج عند نهايته (حسب أوقات دوام الموظف/الشركة).
  Future<void> _scheduleWorkReminders() async {
    final user = widget.user;
    if (user == null) return;
    final tracked = user.role == UserRole.designEmployee ||
        user.role == UserRole.executionEmployee;
    if (!tracked) return;
    try {
      final fs = FirestoreService();
      var reminders = await fs
          .scheduledRemindersOnce()
          .timeout(const Duration(seconds: 10));

      // لا تنبيهات مضبوطة من المدير → افتراضي: دخول عند بداية الدوام، خروج عند نهايته.
      if (reminders.isEmpty) {
        final company = await fs
            .companySettings()
            .first
            .timeout(const Duration(seconds: 10));
        final start = user.workStartMin ?? company.workStartMin;
        final end = user.workEndMin ?? company.workEndMin;
        reminders = [
          ScheduledReminder(
            id: 'default-in',
            title: 'تذكير بتسجيل الدخول',
            body: 'حان وقت الدوام — لا تنسَ تسجيل حضورك بالبصمة من موقع العمل.',
            minute: start,
          ),
          ScheduledReminder(
            id: 'default-out',
            title: 'تذكير بتسجيل الخروج',
            body: 'انتهى الدوام — لا تنسَ تسجيل انصرافك بالبصمة.',
            minute: end,
          ),
        ];
      }
      await ReminderService.instance.syncReminders(reminders);
    } catch (_) {
      // نتجاهل أي فشل (بلا إنترنت مثلاً) دون كسر الجلسة.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: widget.child,
    );
  }
}
