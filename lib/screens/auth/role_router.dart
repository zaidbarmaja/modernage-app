import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/app_user.dart';
import '../accounting/accounting_home.dart';
import '../admin/admin_home.dart';
import '../customer/customer_home.dart';
import '../design/design_home.dart';
import '../execution/execution_home.dart';

/// يفتح الصفحة الرئيسية المناسبة لدور المستخدم.
class RoleRouter extends StatelessWidget {
  final AppUser user;
  const RoleRouter({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    switch (user.role) {
      case UserRole.admin:
        return AdminHome(user: user);
      case UserRole.accounting:
        return AccountingHome(user: user);
      case UserRole.designEmployee:
        return DesignHome(user: user);
      case UserRole.executionEmployee:
        return ExecutionHome(user: user);
      case UserRole.customer:
        return CustomerHome(user: user);
    }
  }
}
