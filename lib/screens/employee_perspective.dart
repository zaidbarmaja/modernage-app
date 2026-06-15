import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'design_screen.dart';
import 'execution_screen.dart';
import 'fingerprint_screen.dart';

/// «منظور الموظف» — مدخل يدخل منه المستخدم إلى التطبيق كموظف عبر كارنيه الدخول
/// (الاسم + الرمز السري)، فيرى صفحاته الخاصة (مشاريعه، تقريره اليومي، بصمته).
class EmployeePerspectiveScreen extends StatelessWidget {
  const EmployeePerspectiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('منظور الموظف')),
      body: PagePadding(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('ادخل التطبيق كموظف',
                intro:
                    'اختر صفحتك ثم سجّل الدخول باسمك ورمزك السري (كارنيه الموظف).'),
            AutoGrid(
              minTileWidth: 240,
              gap: 14,
              children: [
                _card(context, 'موظف تصميم', 'مشاريعك وتقريرك اليومي',
                    Icons.brush_outlined, AppColors.green600,
                    const DesignScreen()),
                _card(context, 'موظف تنفيذ', 'مشاريعك وتقريرك اليومي',
                    Icons.construction_outlined, AppColors.green700,
                    const ExecutionScreen()),
                _card(context, 'نظام البصمة', 'تسجيل الحضور والانصراف',
                    Icons.fingerprint, AppColors.green800,
                    const FingerprintScreen()),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, String title, String sub, IconData icon,
      Color color, Widget screen) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: screen,
          ),
        )),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [color, AppColors.green900],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                    color: Colors.white24, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(sub,
                  style:
                      const TextStyle(color: AppColors.cream200, fontSize: 12)),
              const SizedBox(height: 10),
              const Row(children: [
                Text('دخول',
                    style: TextStyle(color: AppColors.cream100, fontSize: 12)),
                SizedBox(width: 4),
                Icon(Icons.arrow_back, color: Colors.white, size: 16),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
