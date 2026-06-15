import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../services/auth_controller.dart';
import 'login_screen.dart';
import 'role_router.dart';
import 'splash_screen.dart';

/// يوجّه المستخدم حسب حالة الجلسة:
/// غير معروف → سبلاش، غير مسجّل → دخول، مسجّل بملف → حسب الدور،
/// مسجّل بلا ملف / خطأ تحميل → شاشة تنبيه فيها مخرج (خروج/إعادة محاولة).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    switch (auth.status) {
      case AuthStatus.unknown:
        return const SplashScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.authenticated:
        final user = auth.appUser;
        if (user == null) return const SplashScreen();
        return RoleRouter(user: user);
      case AuthStatus.noProfile:
        return const _AccountIssueScreen(
          icon: Icons.person_off_outlined,
          title: 'الحساب غير مكتمل',
          message:
              'تم تسجيل دخولك، لكن لا يوجد ملف لهذا الحساب في النظام بعد.\n'
              'تواصل مع الإدارة لإكمال إنشاء حسابك، أو سجّل الخروج وجرّب حساباً آخر.',
          showRetry: false,
        );
      case AuthStatus.error:
        return const _AccountIssueScreen(
          icon: Icons.cloud_off_outlined,
          title: 'تعذّر تحميل الحساب',
          message:
              'حدث خطأ أثناء تحميل بيانات حسابك.\nتحقّق من اتصالك بالإنترنت ثم أعد المحاولة.',
          showRetry: true,
        );
      case AuthStatus.disabled:
        return const _AccountIssueScreen(
          icon: Icons.block,
          title: 'الحساب معطّل',
          message:
              'تم تعطيل حسابك من قبل الإدارة.\nتواصل مع الإدارة لمزيد من المعلومات.',
          showRetry: false,
        );
    }
  }
}

/// شاشة تنبيه لحالات "لا يوجد ملف مستخدم" و"خطأ التحميل" — مع خروج وإعادة محاولة.
class _AccountIssueScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool showRetry;
  const _AccountIssueScreen({
    required this.icon,
    required this.title,
    required this.message,
    required this.showRetry,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 72, color: AppColors.oliveBright),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.creamDim,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (showRetry) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: auth.retry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: auth.signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('تسجيل الخروج'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
