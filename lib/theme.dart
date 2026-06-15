import 'package:flutter/material.dart';

/// لوحة الألوان مأخوذة من styles.css الأصلي (أخضر زيتوني + كريمي + فحمي).
class AppColors {
  static const green900 = Color(0xFF2B3322);
  static const green800 = Color(0xFF38422C);
  static const green700 = Color(0xFF475438);
  static const green600 = Color(0xFF586A47);
  static const green500 = Color(0xFF6A7D55);
  static const green400 = Color(0xFF869A6F);
  static const green100 = Color(0xFFE6EDDD);

  static const cream50 = Color(0xFFFAF7EF);
  static const cream100 = Color(0xFFF5F0E3);
  static const cream200 = Color(0xFFECE4D1);
  static const cream300 = Color(0xFFDDD2B6);

  static const text = Color(0xFF232A1B);
  static const textSoft = Color(0xFF5D6450);
  static const muted = Color(0xFF8A907C);
  static const line = Color(0xFFE6E0D0);
  static const danger = Color(0xFFB4452F);
  static const dangerSoft = Color(0xFFF6E3DD);
}

class AppTheme {
  static ThemeData build() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.green600,
        primary: AppColors.green600,
        secondary: AppColors.green400,
        surface: AppColors.cream50,
        error: AppColors.danger,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.cream50,
      fontFamily: 'Tajawal',
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.green900,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.green800,
        foregroundColor: AppColors.cream50,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.green600, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green600,
          foregroundColor: AppColors.cream50,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.green700,
          side: const BorderSide(color: AppColors.line),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// عناوين أقسام موحّدة.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? intro;
  const SectionHeader(this.title, {this.intro, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.green900)),
        if (intro != null) ...[
          const SizedBox(height: 4),
          Text(intro!,
              style: const TextStyle(color: AppColors.textSoft, fontSize: 13)),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}
