import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/app_logo.dart';

/// تظهر إذا لم تُضبط إعدادات Firebase بعد (القيم الافتراضية REPLACE_ME).
class SetupNeededScreen extends StatelessWidget {
  const SetupNeededScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 110),
                const SizedBox(height: 24),
                const Text(
                  'عصر الحداثة',
                  style: TextStyle(
                    color: AppColors.cream,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.warning, width: 1),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: AppColors.warning),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'يلزم ضبط إعدادات Firebase أولاً',
                              style: TextStyle(
                                color: AppColors.cream,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 14),
                      Text(
                        'لتشغيل التطبيق على قاعدة بياناتك الخاصة، نفّذ الخطوات التالية ثم أعد التشغيل:\n\n'
                        '1)  أنشئ مشروعاً على console.firebase.google.com\n'
                        '2)  فعّل: Authentication (Email/Password)، Firestore، Storage\n'
                        '3)  ثبّت الأدوات:\n'
                        '      npm install -g firebase-tools\n'
                        '      dart pub global activate flutterfire_cli\n'
                        '4)  من مجلد المشروع نفّذ:\n'
                        '      flutterfire configure\n'
                        '      (سيولّد ملف lib/firebase_options.dart الصحيح)\n\n'
                        'التفاصيل الكاملة في ملف:  SETUP_FIREBASE_AR.md',
                        style: TextStyle(
                          color: AppColors.creamDim,
                          fontSize: 14,
                          height: 1.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
