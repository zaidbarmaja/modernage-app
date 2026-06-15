import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/app_user.dart';
import '../widgets/app_logo.dart';
import 'accounting/accounting_home.dart';
import 'admin/employee_picker.dart';

/// مستخدم إدارة افتراضي (لصفحة المحاسبة في وضع المعاينة).
const AppUser kPreviewAdmin = AppUser(
  uid: 'preview-admin',
  name: 'الإدارة',
  email: '',
  phone: '',
  role: UserRole.admin,
  department: Department.none,
);

/// لوحة التحكم — ثلاثة أبواب فقط:
/// موظفو التصميم، موظفو التنفيذ، المحاسبة.
class ControlPanelScreen extends StatelessWidget {
  const ControlPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_PanelItem>[
      _PanelItem(
        'موظفو التصميم',
        Icons.architecture,
        (_) => const EmployeePickerScreen(
            role: UserRole.designEmployee, title: 'موظفو التصميم'),
      ),
      _PanelItem(
        'موظفو التنفيذ',
        Icons.engineering,
        (_) => const EmployeePickerScreen(
            role: UserRole.executionEmployee, title: 'موظفو التنفيذ'),
      ),
      _PanelItem(
        'المحاسبة',
        Icons.calculate,
        (_) => AccountingHome(user: kPreviewAdmin),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('لوحة التحكم')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const AppLogo(size: 110),
              const SizedBox(height: 12),
              const Text(
                'عصر الحداثة',
                style: TextStyle(
                  color: AppColors.cream,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 28),
              for (final it in items) ...[
                _PanelCard(
                  item: it,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: it.builder),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelItem {
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  _PanelItem(this.label, this.icon, this.builder);
}

class _PanelCard extends StatelessWidget {
  final _PanelItem item;
  final VoidCallback onTap;
  const _PanelCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.olive.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: AppColors.olive.withValues(alpha: 0.6)),
                ),
                child: Icon(item.icon, color: AppColors.oliveBright, size: 34),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(Icons.arrow_back_ios,
                  color: AppColors.creamDim, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
