import 'package:flutter/material.dart';

/// تم‌های Material 3 اپلیکیشن (روشن و تاریک)
///
/// رنگ بذر طلایی انتخاب شده تا با موضوع اپ (قیمت طلا) هماهنگ باشد؛
/// بقیه رنگ‌ها به‌صورت خودکار با ColorScheme.fromSeed تولید می‌شوند.
class AppTheme {
  AppTheme._();

  /// رنگ بذر: طلایی متالیک
  static const Color seedColor = Color(0xFFC8A24B);

  /// فونت فارسی اپلیکیشن
  static const String fontFamily = 'Vazirmatn';

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    final bool isDark = brightness == Brightness.dark;
    final Color scaffold =
        isDark ? const Color(0xFF0F1115) : const Color(0xFFF7F4EE);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
      ),
    );
  }
}
