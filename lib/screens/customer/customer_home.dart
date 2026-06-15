import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../widgets/app_actions.dart';
import 'customer_overview.dart';

/// صفحة الزبون: كامل التفاصيل (الميزانية، مشاريع التصميم، مواقع التنفيذ).
class CustomerHome extends StatelessWidget {
  final AppUser user;
  const CustomerHome({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('صفحتي'),
        actions: const [LogoutAction()],
      ),
      body: CustomerOverview(
        customerUid: user.uid,
        customerName: user.name,
        viewer: user,
      ),
    );
  }
}
