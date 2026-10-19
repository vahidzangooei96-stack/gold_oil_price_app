import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/prices_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // لازم برای استفاده از پکیج‌های پلتفرمی قبل از runApp
  WidgetsFlutterBinding.ensureInitialized();

  // بازیابی منبع داده و کلید API منتخب کاربر از اجرای قبلی
  String? savedSourceId;
  String? savedApiKey;
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    savedSourceId = prefs.getString('data_source_id');
    savedApiKey = prefs.getString('data_source_key');
  } catch (_) {
    // اگر حافظه در دسترس نبود، منبع پیش‌فرض (تالا) استفاده می‌شود
  }

  runApp(GoldOilPriceApp(
    savedSourceId: savedSourceId,
    savedApiKey: savedApiKey,
  ));
}

/// ریشه اپلیکیشن: ثبت Providerها، پیکربندی تم پلنگ صورتی و لوکال فارسی
class GoldOilPriceApp extends StatelessWidget {
  const GoldOilPriceApp({
    super.key,
    this.savedSourceId,
    this.savedApiKey,
    this.pricesProvider,
    this.themeProvider,
  });

  /// منبع داده ذخیره‌شده کاربر از اجرای قبلی
  final String? savedSourceId;

  /// کلید API ذخیره‌شده (برای منابع کلیددار)
  final String? savedApiKey;

  /// Providerهای قابل تزریق؛ فقط برای تست‌ها استفاده می‌شود
  /// و در اجرای واقعی مقدار null است.
  final PricesProvider? pricesProvider;
  final ThemeProvider? themeProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<ThemeProvider>(
          create: (BuildContext context) => themeProvider ?? ThemeProvider(),
        ),
        ChangeNotifierProvider<PricesProvider>(
          create: (BuildContext context) {
            final PricesProvider provider = pricesProvider ??
                PricesProvider(
                  savedSourceId: savedSourceId,
                  apiKey: savedApiKey,
                );
            // فقط در اجرای واقعی: دریافت اولین داده + شروع آپدیت خودکار
            if (pricesProvider == null) {
              provider.fetchAll();
              provider.startAutoRefresh();
            }
            return provider;
          },
        ),
      ],
      child: const _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    final ThemeMode themeMode = context.watch<ThemeProvider>().themeMode;

    return MaterialApp(
      title: 'قیمت لحظه‌ای طلا و نفت',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: const Locale('fa'),
      supportedLocales: const <Locale>[Locale('fa'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
    );
  }
}
