import 'package:flutter/material.dart';

/// تم «پلنگ صورتی» اپلیکیشن (Material 3)
///
/// صورتیِ براق پلنگ روی بادمجانیِ تیره در حالت تاریک،
/// و گل‌بهیِ روشن با آلوییِ اشباع در حالت روشن.
/// تمام متن‌های اپ فارسی است.
class AppTheme {
  AppTheme._();

  /// صورتی اصلی پلنگ (رنگ بذر تم)
  static const Color pink = Color(0xFFEC4899);

  /// صورتی روشن برای متن‌ها و هایلایت‌ها روی زمینه تاریک
  static const Color pinkLight = Color(0xFFF9A8D4);

  /// آلویی تیره برای متن روی زمینه روشن
  static const Color plumDark = Color(0xFF3B0E26);

  /// گل‌بهی روشن برای متن روی زمینه تاریک
  static const Color roseWhite = Color(0xFFFDF2F7);

  /// پس‌زمینه کارت در حالت تاریک (بادمجانی عمیق)
  static const Color cardDark = Color(0xFF24101C);

  /// پس‌زمینه کارت در حالت روشن
  static const Color cardLight = Color(0xFFFFF4F8);

  /// سبز موفقیت (افزایش قیمت)
  static const Color gain = Color(0xFF34D399);

  /// قرمز کاهش قیمت
  static const Color loss = Color(0xFFF87171);

  /// گرادیان پس‌زمینه حالت تاریک (بادمجانی پلنگ)
  static const List<Color> darkGradient = <Color>[
    Color(0xFF1A0A13),
    Color(0xFF210D19),
    Color(0xFF2A1120),
  ];

  /// گرادیان پس‌زمینه حالت روشن (گل‌بهی نرم)
  static const List<Color> lightGradient = <Color>[
    Color(0xFFFDF1F6),
    Color(0xFFFBE7F0),
    Color(0xFFF7DCE9),
  ];

  /// گرادیان صورتی برای آیکون‌ها و نشان‌ها
  static const List<Color> pinkGradient = <Color>[
    Color(0xFFF472B6),
    Color(0xFFDB2777),
  ];

  /// فونت فارسی اپلیکیشن
  static const String fontFamily = 'Vazirmatn';

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: pink,
      brightness: brightness,
    ).copyWith(
      primary: pink,
      onPrimary: isDark ? const Color(0xFF2B0A1B) : Colors.white,
      secondary: pink,
      surface: isDark ? cardDark : cardLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF1A0A13) : const Color(0xFFFDF1F6),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? pinkLight : plumDark,
      ),
      iconTheme: IconThemeData(color: isDark ? pinkLight : plumDark),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: pink),
      dividerTheme: DividerThemeData(color: pink.withOpacity(0.25)),
    );
  }
}
