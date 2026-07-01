import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../services/firestore_service.dart';
import '../../widgets/ui.dart';
import '../accounting/accounting_home.dart';
import '../customer/customer_home.dart';
import '../design/design_home.dart';
import '../execution/execution_home.dart';
import 'add_employee_form.dart';

/// إدارة الموظفين: إضافتهم منظّمين حسب الوظيفة (تصميم/تنفيذ/محاسبة)
/// مع أرقامهم، وفتح صفحة كل موظف للعمل نيابةً عنه.
class EmployeesManagementScreen extends StatelessWidget {
  const EmployeesManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الموظفين')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEmployeeForm()),
        ),
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة موظف'),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: fs.allUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          final users = snapshot.data ?? [];
          final design =
              users.where((u) => u.role == UserRole.designEmployee).toList();
          final execution =
              users.where((u) => u.role == UserRole.executionEmployee).toList();
          final accounting =
              users.where((u) => u.role == UserRole.accounting).toList();
          final customers =
              users.where((u) => u.role == UserRole.customer).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            children: [
              _section(context, 'موظفو التصميم', Icons.architecture, design),
              _section(context, 'موظفو التنفيذ', Icons.engineering, execution),
              _section(context, 'المحاسبة', Icons.calculate, accounting),
              _section(context, 'الزبائن', Icons.people, customers),
            ],
          );
        },
      ),
    );
  }

  Widget _section(
      BuildContext context, String title, IconData icon, List<AppUser> users) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionCard(
        title: '$title (${users.length})',
        icon: icon,
        child: users.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('لا يوجد بعد',
                    style: TextStyle(color: AppColors.creamDim)),
              )
            : Column(
                children: users.map((u) => _tile(context, u)).toList(),
              ),
      ),
    );
  }

  Widget _tile(BuildContext context, AppUser u) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.oliveDark,
                child: Icon(u.role.icon, color: AppColors.cream, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.name.isEmpty ? 'بدون اسم' : u.name,
                        style: const TextStyle(
                            color: AppColors.cream,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      '${u.phone.isEmpty ? 'بدون رقم' : u.phone}'
                      '${u.department != Department.none ? ' • ${u.department.labelAr}' : ''}',
                      style: const TextStyle(color: AppColors.creamDim),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: AppColors.surfaceAlt,
                icon: const Icon(Icons.more_vert, color: AppColors.creamDim),
                onSelected: (v) => _onMenu(context, u, v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  PopupMenuItem(value: 'delete', child: Text('حذف')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openAs(context, u),
              icon: const Icon(Icons.login, size: 18),
              label: const Text('فتح صفحته والعمل نيابةً عنه'),
            ),
          ),
        ],
      ),
    );
  }

  void _onMenu(BuildContext context, AppUser u, String action) async {
    if (action == 'edit') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AddEmployeeForm(existing: u)),
      );
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('حذف', style: TextStyle(color: AppColors.cream)),
          content: Text('حذف ${u.name}؟',
              style: const TextStyle(color: AppColors.creamDim)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء',
                    style: TextStyle(color: AppColors.creamDim))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف',
                    style: TextStyle(color: AppColors.danger))),
          ],
        ),
      );
      if (ok == true) {
        await FirestoreService().deleteUserPermanently(u.uid);
        if (context.mounted) showSnack(context, 'تم الحذف نهائياً');
      }
    }
  }

  void _openAs(BuildContext context, AppUser u) {
    Widget page;
    switch (u.role) {
      case UserRole.designEmployee:
        page = DesignHome(user: u);
        break;
      case UserRole.executionEmployee:
        page = ExecutionHome(user: u);
        break;
      case UserRole.accounting:
        page = AccountingHome(user: u);
        break;
      case UserRole.customer:
        page = CustomerHome(user: u);
        break;
      case UserRole.admin:
        page = AccountingHome(user: u);
        break;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}
