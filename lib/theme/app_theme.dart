import 'package:flutter/material.dart';

/// تم فانتزی صورتی-آبی اپلیکیشن (Material 3)
///
/// پس‌زمینه گرادیانی صورتی↔آبی در حالت روشن و بنفش-شبانه در حالت تاریک،
/// با رنگ بذر صورتی و رنگ دوم آبی آسمانی.
class AppTheme {
  AppTheme._();

  /// رنگ بذر: صورتی فانتزی
  static const Color seedPink = Color(0xFFF472B6);

  /// رنگ دوم: آبی آسمانی
  static const Color skyBlue = Color(0xFF5BA8F5);

  /// گرادیان پس‌زمینه حالت روشن (صورتی ↔ آبی پاستلی)
  static const List<Color> lightGradient = <Color>[
    Color(0xFFFFD9EC),
    Color(0xFFD6EBFF),
    Color(0xFFFFE7F4),
  ];

  /// گرادیان پس‌زمینه حالت تاریک (شب بنفش-آبی فانتزی)
  static const List<Color> darkGradient = <Color>[
    Color(0xFF170F30),
    Color(0xFF1D1440),
    Color(0xFF2A1650),
  ];

  /// فونت فارسی اپلیکیشن
  static const String fontFamily = 'Vazirmatn';

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final ColorScheme base = ColorScheme.fromSeed(
      seedColor: seedPink,
      brightness: brightness,
    );

    final ColorScheme scheme = base.copyWith(
      secondary: brightness == Brightness.dark
          ? const Color(0xFF8FC7FF)
          : skyBlue,
    );

    final bool isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF170F30) : const Color(0xFFFDF2F8),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }
}
