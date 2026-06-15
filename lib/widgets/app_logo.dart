import 'package:flutter/material.dart';

import '../core/theme.dart';

/// شعار التطبيق: يعرض الصورة من assets/images/logo.png،
/// وإن لم تتوفر يرسم شعاراً بديلاً بنفس ألوان اللوكو.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => _FallbackLogo(size: size),
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  final double size;
  const _FallbackLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.olive,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.cream, width: size * 0.04),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.apartment_rounded,
              size: size * 0.42, color: AppColors.cream),
          SizedBox(height: size * 0.02),
          Text(
            'عصر الحداثة',
            style: TextStyle(
              color: AppColors.cream,
              fontSize: size * 0.13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
