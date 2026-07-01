import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../../services/auth_controller.dart';
import '../../services/push_service.dart';
import '../accounting/accounting_home.dart';
import '../admin/admin_home.dart';
import '../customer/customer_home.dart';
import '../design/design_home.dart';
import '../execution/execution_home.dart';
import '../location_gate.dart';

/// يفتح الصفحة الرئيسية المناسبة لدور المستخدم، ويسجّل جهازه لاستقبال الإشعارات
/// الفورية (FCM).
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
    // تسجيل الجهاز للإشعارات الفورية للمستخدم الحقيقي فقط (لا أثناء انتحال الأدمن
    // لحساب موظف، كي لا يُربط رمز جهاز الأدمن بحساب غيره).
    try {
      if (!context.read<AuthController>().isImpersonating) {
        PushService.instance.register(widget.user.uid);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    // الإدارة والموظفون خلف بوابة الجلسة (تذكيرات الدوام). الزبون بلا بوابة.
    switch (user.role) {
      case UserRole.admin:
        return LocationGate(child: AdminHome(user: user));
      case UserRole.accounting:
        return LocationGate(child: AccountingHome(user: user));
      case UserRole.designEmployee:
        return LocationGate(user: user, child: DesignHome(user: user));
      case UserRole.executionEmployee:
        return LocationGate(user: user, child: ExecutionHome(user: user));
      case UserRole.customer:
        return CustomerHome(user: user);
    }
  }
}
