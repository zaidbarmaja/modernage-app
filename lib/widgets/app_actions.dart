import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/auth_controller.dart';

/// زر تسجيل الخروج المستخدم في كل الصفحات الرئيسية.
class LogoutAction extends StatelessWidget {
  const LogoutAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'تسجيل الخروج',
      icon: const Icon(Icons.logout, color: AppColors.cream),
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('تسجيل الخروج',
                style: TextStyle(color: AppColors.cream)),
            content: const Text('هل تريد تسجيل الخروج من التطبيق؟',
                style: TextStyle(color: AppColors.creamDim)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء',
                    style: TextStyle(color: AppColors.creamDim)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('خروج',
                    style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          await context.read<AuthController>().signOut();
        }
      },
    );
  }
}
