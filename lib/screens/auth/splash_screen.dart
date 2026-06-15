import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/app_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 140),
            const SizedBox(height: 28),
            const Text(
              'عصر الحداثة',
              style: TextStyle(
                color: AppColors.cream,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'للتصميم والإشراف والتنفيذ الهندسي',
              style: TextStyle(color: AppColors.creamDim, fontSize: 14),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: AppColors.oliveBright,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
