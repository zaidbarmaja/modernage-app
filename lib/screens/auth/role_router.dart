import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../../services/auth_controller.dart';
import '../../services/notifications.dart';
import '../accounting/accounting_home.dart';
import '../admin/admin_home.dart';
import '../customer/customer_home.dart';
import '../design/design_home.dart';
import '../execution/execution_home.dart';
import '../location_gate.dart';

/// يفتح الصفحة الرئيسية المناسبة لدور المستخدم، ويسجّل جهازه للإشعارات الفورية
/// (FCM)، ويجدول تنبيهاته اليومية المحلية (حسب فئته) — عبر NotificationService.
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
        Notifications.registerDevice(widget.user.uid);
        Notifications.syncDailyReminders(widget.user);
      }
    } catch (_) {}
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
