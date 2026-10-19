import 'package:flutter/material.dart';

/// تم لوکس «سیاه و طلایی» اپلیکیشن (Material 3)
///
/// الهام از طرح‌های امپراتوری مالی: پس‌زمینه مشکیِ عمیق با طلای براق
/// در حالت تاریک، و عاج گرم با برنز تیره در حالت روشن.
/// تمام متن‌های اپ فارسی است.
class AppTheme {
  AppTheme._();

  /// طلای اصلی (رنگ بذر تم)
  static const Color gold = Color(0xFFD4AF37);

  /// طلای روشن برای متن‌ها و هایلایت‌ها روی زمینه تاریک
  static const Color goldLight = Color(0xFFF1D689);

  /// برنز تیره برای متن روی زمینه روشن (عاج)
  static const Color bronzeDark = Color(0xFF2B2113);

  /// عاج روشن برای متن روی زمینه تاریک
  static const Color ivory = Color(0xFFF3EBD3);

  /// پس‌زمینه کارت در حالت تاریک
  static const Color cardDark = Color(0xFF17130B);

  /// پس‌زمینه کارت در حالت روشن
  static const Color cardLight = Color(0xFFFFFBF0);

  /// سبز موفقیت (افزایش قیمت)
  static const Color gain = Color(0xFF3DBE7B);

  /// قرمز کاهش قیمت
  static const Color loss = Color(0xFFE05252);

  /// گرادیان پس‌زمینه حالت تاریک (مشکی امپراتوری)
  static const List<Color> darkGradient = <Color>[
    Color(0xFF0B0A08),
    Color(0xFF12100B),
    Color(0xFF1A160E),
  ];

  /// گرادیان پس‌زمینه حالت روشن (عاج گرم)
  static const List<Color> lightGradient = <Color>[
    Color(0xFFF8F3E6),
    Color(0xFFF4EBD8),
    Color(0xFFEFE3C8),
  ];

  /// گرادیان طلایی برای آیکون‌ها و نشان‌ها
  static const List<Color> goldGradient = <Color>[
    Color(0xFFB8912E),
    Color(0xFFF1D689),
  ];

  /// فونت فارسی اپلیکیشن
  static const String fontFamily = 'Vazirmatn';

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: brightness,
    ).copyWith(
      primary: gold,
      onPrimary: isDark ? const Color(0xFF14110B) : Colors.white,
      secondary: gold,
      surface: isDark ? cardDark : cardLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0B0A08) : const Color(0xFFF8F3E6),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? goldLight : bronzeDark,
      ),
      iconTheme: IconThemeData(color: isDark ? goldLight : bronzeDark),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: gold),
      dividerTheme: DividerThemeData(color: gold.withOpacity(0.25)),
    );
  }
}
