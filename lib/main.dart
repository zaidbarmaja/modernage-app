import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'core/theme.dart';
import 'services/auth_controller.dart';
import 'services/connectivity_service.dart';
import 'services/push_service.dart';
import 'services/reminder_service.dart';
import 'services/session.dart';
import 'widgets/common.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/connectivity_gate.dart';

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
  // معالج إشعارات الخلفية (FCM) — يجب تسجيله على مستوى أعلى قبل تشغيل التطبيق.
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('FCM background handler error: $e');
  }
  // تقليل استهلاك قراءات Firestore: تفعيل التخزين المؤقّت المحلي (cache). تُخدَم
  // القراءات المتكرّرة من الكاش وتُقرأ من الخادم التغييرات فقط — يبقى التحديث حيًّا
  // عند الاتصال (بوابة الاتصال تضمن العمل أونلاين). لا يؤثّر على تطبيق الويب.
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firestore settings error: $e');
  }
  // تهيئة خدمة التذكيرات المحلية (تُتجاهَل على الويب).
  await ReminderService.instance.init();
  runApp(const AsrApp());
}

class AsrApp extends StatelessWidget {
  const AsrApp({super.key});

  @override
  Widget build(BuildContext context) {
    // AuthController يستمع لحالة تسجيل الدخول ويحمّل ملف المستخدم،
    // ليتمكّن AuthGate من التوجيه حسب الدور.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
      ],
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
        // المهمة #1: بوابة الاتصال تحجب التطبيق كلياً عند غياب الإنترنت.
        home: const ConnectivityGate(child: AuthGate()),
      ),
    );
  }
}
