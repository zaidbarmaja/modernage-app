import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'core/theme.dart';
import 'services/auth_controller.dart';
import 'services/session.dart';
import 'widgets/common.dart';
import 'screens/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // واجهة خطأ ودّية بدل الشاشة البيضاء/الحمراء عند أي خطأ في بناء الواجهة.
  ErrorWidget.builder = (FlutterErrorDetails details) =>
      FriendlyError(details: details);

  await initializeDateFormatting('ar');
  await Session.init();
  try {
    // تفادي خطأ duplicate-app إن كانت الإضافة الأصلية قد هيّأت Firebase تلقائيًا.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // يُسجّل الخطأ فقط؛ تظهر الشاشات وتعرض حالات الاتصال.
    debugPrint('Firebase init error: $e');
  }
  runApp(const AsrApp());
}

class AsrApp extends StatelessWidget {
  const AsrApp({super.key});

  @override
  Widget build(BuildContext context) {
    // AuthController يستمع لحالة تسجيل الدخول ويحمّل ملف المستخدم،
    // ليتمكّن AuthGate من التوجيه حسب الدور.
    return ChangeNotifierProvider(
      create: (_) => AuthController(),
      child: MaterialApp(
        title: 'عصر الحداثة',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
        home: const AuthGate(),
      ),
    );
  }
}
