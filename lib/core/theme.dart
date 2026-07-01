import 'package:flutter/material.dart';

/// ثيم «زيتوني هادئ» — مطابق لشعار «عصر الحداثة» وألوانه الزيتونية، بدرجات
/// دافئة مريحة للعين: خلفية زيتونية داكنة (لا سوداء قاسية)، تمييز أخضر زيتوني
/// هادئ، ونص فاتح دافئ بتباين معتدل.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF161911); // أسود زيتوني داكن دافئ
  static const Color surface = Color(0xFF20241A); // بطاقة زيتونية داكنة
  static const Color surfaceAlt = Color(0xFF2B3122);

  static const Color olive = Color(0xFF7C8A57); // الأخضر الزيتوني الأساسي (تمييز)
  static const Color oliveDark = Color(0xFF515E39);
  static const Color oliveBright = Color(0xFFA8BA82); // أخضر زيتوني فاتح

  static const Color cream = Color(0xFFECEFE1); // النص الفاتح الدافئ الأساسي
  static const Color creamDim = Color(0xFFAEB5A0); // نص ثانوي باهت

  static const Color success = Color(0xFF7BA86B);
  static const Color danger = Color(0xFFCB6B62);
  static const Color warning = Color(0xFFD8AC5A);

  static const LinearGradient oliveGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [olive, oliveDark],
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'Tajawal',
    );
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.olive,
      brightness: Brightness.dark,
      primary: AppColors.olive,
      onPrimary: AppColors.cream,
      secondary: AppColors.oliveBright,
      surface: AppColors.surface,
      onSurface: AppColors.cream,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: colorScheme,
      primaryColor: AppColors.olive,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.cream,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.cream,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x33ECEFE1), width: 0.6),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.olive,
          foregroundColor: AppColors.cream,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cream,
          side: const BorderSide(color: AppColors.olive, width: 1.4),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        hintStyle: const TextStyle(color: AppColors.creamDim),
        labelStyle: const TextStyle(color: AppColors.creamDim),
        prefixIconColor: AppColors.oliveBright,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x33ECEFE1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.olive, width: 1.6),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.cream),
      dividerColor: const Color(0x22ECEFE1),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.cream,
        displayColor: AppColors.cream,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.cream,
        unselectedItemColor: AppColors.creamDim,
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceAlt,
        contentTextStyle: TextStyle(color: AppColors.cream),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.olive,
        foregroundColor: AppColors.cream,
      ),
    );
  }
}
