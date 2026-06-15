// اختبار بسيط: عند عدم ضبط Firebase تظهر شاشة الإعداد باسم التطبيق.
import 'package:flutter_test/flutter_test.dart';

import 'package:mohameed_app/main.dart';

void main() {
  testWidgets('يعرض اسم التطبيق "عصر الحداثة"', (WidgetTester tester) async {
    await tester.pumpWidget(const AsrApp());
    await tester.pump();

    expect(find.text('عصر الحداثة'), findsWidgets);
  });
}
