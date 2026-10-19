import 'package:flutter/material.dart';

/// مدیریت پوسته اپلیکیشن: سیستم / روشن / تاریک
///
/// با دکمه موجود در AppBar کاربر می‌تواند بین سه حالت جابه‌جا شود.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  /// تغییر چرخه‌ای پوسته: سیستم → تاریک → روشن → سیستم
  void toggle() {
    _themeMode = switch (_themeMode) {
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.light => ThemeMode.system,
      ThemeMode.system => ThemeMode.dark,
    };
    notifyListeners();
  }

  /// متن راهنمای دکمه تغییر پوسته (برای tooltip)
  String get tooltip => switch (_themeMode) {
        ThemeMode.dark => 'پوسته روشن',
        ThemeMode.light => 'پوسته تاریک',
        ThemeMode.system => 'پوسته تاریک',
      };
}
