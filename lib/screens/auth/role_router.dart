import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../../services/auth_controller.dart';
import '../../services/firestore_service.dart';
import '../../services/push_service.dart';
import '../../services/reminder_service.dart';
import '../accounting/accounting_home.dart';
import '../admin/admin_home.dart';
import '../customer/customer_home.dart';
import '../design/design_home.dart';
import '../execution/execution_home.dart';
import '../location_gate.dart';

/// يفتح الصفحة الرئيسية المناسبة لدور المستخدم، ويسجّل جهازه للإشعارات الفورية
/// (FCM)، ويجدول تنبيهاته اليومية المحلية (حسب الفئة المستهدفة من الداشبورد).
class RoleRouter extends StatefulWidget {
  final AppUser user;
  const RoleRouter({super.key, required this.user});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  @override
  void initState() {
    super.initState();
    // للمستخدم الحقيقي فقط (لا أثناء انتحال الأدمن لحساب موظف).
    try {
      if (!context.read<AuthController>().isImpersonating) {
        PushService.instance.register(widget.user.uid);
        _syncReminders(widget.user);
      }
    } catch (_) {}
  }

  /// يجدول التنبيهات اليومية المحلية لهذا المستخدم: **فقط** ما ضبطه المدير من
  /// الداشبورد وطابق فئته. لا يُنشئ التطبيق أي تنبيه من تلقاء نفسه؛ فإن لم يضبط
  /// المدير شيئاً لا يُجدوَل شيء.
  Future<void> _syncReminders(AppUser user) async {
    try {
      final all = await FirestoreService()
          .scheduledRemindersOnce()
          .timeout(const Duration(seconds: 10));
      final reminders = all.where((r) => r.matchesUser(user)).toList();
      await ReminderService.instance.syncReminders(reminders);
    } catch (_) {
      // نتجاهل أي فشل (بلا إنترنت مثلاً) دون كسر الجلسة.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    switch (user.role) {
      case UserRole.admin:
        return LocationGate(child: AdminHome(user: user));
      case UserRole.accounting:
        return LocationGate(child: AccountingHome(user: user));
      case UserRole.designEmployee:
        return LocationGate(child: DesignHome(user: user));
      case UserRole.executionEmployee:
        return LocationGate(child: ExecutionHome(user: user));
      case UserRole.customer:
        return CustomerHome(user: user);
    }
  }
}
