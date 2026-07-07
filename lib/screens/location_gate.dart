import 'package:flutter/material.dart';

import '../core/theme.dart';

/// غلاف بسيط لجلسة المستخدم. لم يعد يطلب الموقع مسبقاً ولا يشغّل تتبّعاً بالخلفية —
/// تسجيل الحضور يدوي (زر + بصمة) ويُطلب الموقع «أثناء الاستخدام» لحظة الضغط فقط.
/// تهيئة الإشعارات وجدولة التنبيهات تتمّان في RoleRouter/main.
class LocationGate extends StatelessWidget {
  final Widget child;
  const LocationGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(color: AppColors.background, child: child);
  }
}
