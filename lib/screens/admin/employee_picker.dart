import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../services/firestore_service.dart';
import '../../widgets/ui.dart';
import '../design/design_home.dart';
import '../execution/execution_home.dart';
import 'add_employee_form.dart';

/// شاشة اختيار الموظف حسب الوظيفة (تصميم/تنفيذ):
/// يختار الموظف اسمه — الذي أضافته الإدارة — فتفتح صفحته.
class EmployeePickerScreen extends StatelessWidget {
  final UserRole role;
  final String title;
  const EmployeePickerScreen({
    super.key,
    required this.role,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEmployeeForm()),
        ),
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة موظف'),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: fs.usersByRole(role),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          final employees = snapshot.data ?? [];
          if (employees.isEmpty) {
            return const EmptyState(
              message:
                  'لا يوجد موظفون بعد.\nاضغط "إضافة موظف" لإضافة الموظفين أولاً.',
              icon: Icons.badge_outlined,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8, right: 4),
                child: Text('اختر اسمك للدخول إلى صفحتك:',
                    style: TextStyle(color: AppColors.creamDim, fontSize: 14)),
              ),
              ...employees.map((u) => Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.oliveDark,
                        child: Icon(role.icon, color: AppColors.cream),
                      ),
                      title: Text(u.name.isEmpty ? u.phone : u.name,
                          style: const TextStyle(
                              color: AppColors.cream,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      subtitle: Text(
                        '${u.phone}'
                        '${u.department != Department.none ? ' • ${u.department.labelAr}' : ''}',
                        style: const TextStyle(color: AppColors.creamDim),
                      ),
                      trailing: const Icon(Icons.arrow_back_ios,
                          color: AppColors.oliveBright, size: 18),
                      onTap: () => _open(context, u),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }

  void _open(BuildContext context, AppUser u) {
    final Widget page = role == UserRole.executionEmployee
        ? ExecutionHome(user: u)
        : DesignHome(user: u);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}
