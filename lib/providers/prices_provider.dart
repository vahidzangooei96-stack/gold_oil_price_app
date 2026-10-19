import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/price_models.dart';
import '../services/api_exception.dart';
import '../services/source_registry.dart';
import '../services/sources/market_source.dart';
import '../services/yahoo_service.dart';

/// مدیریت State قیمت‌ها با Provider (الگوی ChangeNotifier)
///
/// - دریافت قیمت‌ها از منبع داده منتخب کاربر + نفت یاهو، هر ۳۰ ثانیه
/// - قابلیت «تغییر منبع داده» توسط کاربر با ذخیره‌سازی انتخاب (SharedPreferences)
/// - شمارش معکوس زنده تا رفرش بعدی (با تیکر ۱ ثانیه‌ای)
/// - در صورت شکست رفرش، بعد از ۱۰ ثانیه دوباره تلاش می‌کند
/// - توقف/ادامه آپدیت بر اساس چرخه حیات اپ (بهینه‌سازی باتری)
class PricesProvider extends ChangeNotifier with WidgetsBindingObserver {
  PricesProvider({
    MarketSource? source,
    String? apiKey,
    String? savedSourceId,
    YahooService? yahooService,
  })  : _source = source ??
            SourceRegistry.create(
              _validatedSourceId(savedSourceId),
              apiKey: apiKey,
            ),
        _apiKey = apiKey ?? '',
        _yahoo = yahooService ?? YahooService() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// اعتبارسنجی شناسه ذخیره‌شده؛ اگر نامعتبر بود، منبع پیش‌فرض برمی‌گردد
  static String _validatedSourceId(String? id) {
    if (id != null &&
        SourceRegistry.options.any((SourceOption o) => o.id == id)) {
      return id;
    }
    return SourceRegistry.defaultId;
  }

  MarketSource _source;
  String _apiKey;
  final YahooService _yahoo;

  /// کلیدهای ذخیره‌سازی انتخاب کاربر
  static const String _prefSourceId = 'data_source_id';
  static const String _prefSourceKey = 'data_source_key';

  /// تیکر ۱ ثانیه‌ای برای شمارش معکوس و اجرای رفرش دوره‌ای
  Timer? _ticker;

  /// جلوگیری از درخواست‌های هم‌زمان و هم‌پوشان
  bool _isFetching = false;

  /// جلوگیری از تداخل عملیات تعویض منبع
  bool _isSwitching = false;

  /// منبع داده فعال
  MarketSource get source => _source;

  /// شناسه منبع داده فعال
  String get sourceId => _source.id;

  /// نام فارسی منبع داده فعال (برای نمایش در UI)
  String get sourceName => _source.displayName;

  /// آیا منبع فعال به کلید API نیاز دارد؟
  bool get sourceRequiresKey => _source.requiresKey;

  /// کلید API ذخیره‌شده (برای منابع کلیددار مثل API رسمی تالا)
  String get apiKey => _apiKey;

  /// گزینه‌های منبع داده برای شیت تنظیمات
  List<SourceOption> get sourceOptions => SourceRegistry.options;

  /// لیست قیمت‌های خام منبع ایرانی (قبل از ادغام با نفت یاهو)
  List<PriceRow> sourceItems = const <PriceRow>[];

  /// لیست قیمت‌های نفت از یاهو (برنت و WTI)
  List<PriceRow> oilItems = const <PriceRow>[];

  /// لیست نهایی ترکیبی برای نمایش (همه گروه‌ها)
  List<PriceRow> items = const <PriceRow>[];

  /// زمان شمسی آخرین بروزرسانی به‌صورت متن (از خود سایت)
  String? jdate;

  /// مُهر زمانی خودِ داده از سرور (میلی‌ثانیه) — برای محاسبه «سن داده»
  int? feedTimeMs;

  /// زمان دستگاه در آخرین دریافت موفق — برای نمایش «آخرین دریافت»
  DateTime? lastFetchAt;

  /// آیا در حال بارگذاری هستیم؟ (بارگذاری اولیه یا رفرش دستی)
  bool isLoading = true;

  /// پیام خطای فارسی برای نمایش در UI (null یعنی بدون خطا)
  String? errorMessage;

  /// خطای اختصاصی بخش نفت (وقتی فقط یاهو در دسترس نیست ولی بقیه داده داریم)
  String? oilError;

  /// ثانیه‌های باقی‌مانده تا رفرش بعدی (شمارش معکوس زنده)
  int secondsToNextRefresh = autoRefreshSeconds;

  /// فاصله آپدیت خودکار بر حسب ثانیه (۳۰ ثانیه)
  static const int autoRefreshSeconds = 30;

  /// بعد از شکست، زودتر دوباره تلاش می‌کنیم (۱۰ ثانیه)
  static const int _retrySeconds = 10;

  /// آیا داده‌های روی صفحه قدیمی محسوب می‌شوند؟
  /// (بیش از ۹۰ ثانیه از آخرین دریافت موفق گذشته باشد)
  bool get isStale {
    final DateTime? at = lastFetchAt;
    if (at == null) return true;
    return DateTime.now().difference(at) >
        const Duration(seconds: autoRefreshSeconds * 3);
  }

  /// سن داده بر حسب ثانیه (اختلاف الان با مُهر زمانی سرور)
  int? get dataAgeSeconds {
    final int? ms = feedTimeMs;
    if (ms == null) return null;
    final int age = DateTime.now().millisecondsSinceEpoch - ms;
    return age < 0 ? 0 : age ~/ 1000;
  }

  // ───────────────────── تعویض منبع داده ─────────────────────

  /// تعویض منبع داده توسط کاربر + ذخیره‌سازی انتخاب
  ///
  /// اگر [id] همان منبع فعلی باشد و کلید تغییر نکرده باشد، کاری نمی‌کند.
  /// برای منابع کلیددار، [apiKey] کلید شخصی کاربر است.
  Future<void> switchSource(String id, {String? apiKey}) async {
    if (_isSwitching) return;

    final bool sameSource = id == _source.id;
    final String newKey = apiKey?.trim() ?? _apiKey;
    final bool keyChanged =
        sameSource && _source.requiresKey && newKey != _apiKey;
    if (sameSource && !keyChanged) return;

    _isSwitching = true;
    try {
      // آزادسازی منبع قبلی و ساخت منبع جدید
      _source.dispose();
      _source = SourceRegistry.create(id, apiKey: newKey);
      _apiKey = newKey;

      // ذخیره انتخاب کاربر (اگر فضای ذخیره‌سازی در دسترس نبود، اپ باز هم کار می‌کند)
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefSourceId, id);
        if (newKey.isEmpty) {
          await prefs.remove(_prefSourceKey);
        } else {
          await prefs.setString(_prefSourceKey, newKey);
        }
      } catch (_) {
        // ذخیره‌سازی حیاتی نیست؛ ادامه می‌دهیم
      }

      // پاک‌سازی وضعیت برای بارگذاری تازه
      sourceItems = const <PriceRow>[];
      oilItems = const <PriceRow>[];
      items = const <PriceRow>[];
      jdate = null;
      feedTimeMs = null;
      lastFetchAt = null;
      errorMessage = null;
      oilError = null;
      isLoading = true;
      secondsToNextRefresh = autoRefreshSeconds;
      notifyListeners();

      await fetchAll();
    } finally {
      _isSwitching = false;
    }
  }

  /// ذخیره کلید API برای منبع فعال (API رسمی تالا) و دریافت دوباره قیمت‌ها
  Future<void> saveApiKey(String key) async {
    final String trimmed = key.trim();
    if (trimmed.isEmpty) return;
    if (!_source.requiresKey) return;
    await switchSource(_source.id, apiKey: trimmed);
  }

  // ───────────────────── دریافت قیمت‌ها ─────────────────────

  /// دریافت قیمت‌ها از هر دو منبع به‌صورت موازی:
  ///  ۱) منبع ایرانی منتخب کاربر — طلا، سکه، ارز (و برنت پشتیبان)
  ///  ۲) Yahoo Finance — برنت و WTI لحظه‌ای
  ///
  /// خطای هر منبع مستقل مهار می‌شود تا شکست یکی، بقیه را از کار نیندازد.
  Future<void> fetchAll({bool showLoading = true}) async {
    if (_isFetching) return;
    _isFetching = true;

    if (showLoading) {
      isLoading = true;
      errorMessage = null;
      notifyListeners();
    }

    try {
      final List<Object?> results = await Future.wait(<Future<Object?>>[
        _source
            .fetchSnapshot()
            .then<Object?>((MarketSnapshot s) => s)
            .catchError((Object e) => e),
        _yahoo
            .fetchOilQuotes()
            .then<Object?>((List<PriceRow> r) => r)
            .catchError((Object e) => e),
      ]);

      final Object? sourceRes = results[0];
      final Object? oilRes = results[1];

      // ── منبع اصلی: منبع ایرانی منتخب ──
      if (sourceRes is MarketSnapshot) {
        _applySnapshot(sourceRes);
      } else if (items.isEmpty && sourceItems.isEmpty) {
        // اولین دریافت هم شکست خورده → خطای کامل
        final String msg = sourceRes is ApiException
            ? sourceRes.message
            : 'خطا در دریافت اطلاعات؛ اتصال اینترنت را بررسی کنید.';
        _handleError(msg);
        return;
      } else {
        // داده قبلی داریم؛ فقط هشدار بده
        errorMessage = sourceRes is ApiException
            ? sourceRes.message
            : 'خطا در دریافت اطلاعات؛ اتصال اینترنت را بررسی کنید.';
      }

      // ── منبع نفت: یاهو، با پشتیبانِ برنتِ منبع ایرانی ──
      if (oilRes is List<PriceRow> && oilRes.isNotEmpty) {
        oilItems = oilRes;
        oilError = null;
        // سن داده نفت از خود یاهو
        final int? rmt = _yahoo.lastMarketTimeMs;
        if (rmt != null && (feedTimeMs == null || rmt > feedTimeMs!)) {
          feedTimeMs = rmt;
        }
      } else {
        oilItems = const <PriceRow>[];
        oilError = sourceItems.any((PriceRow r) => r.group == 'oil')
            ? null
            : 'قیمت نفت جهانی موقتاً در دسترس نیست.';
      }

      // ترکیب نهایی ردیف‌ها
      _mergeItems();

      lastFetchAt = DateTime.now();
      isLoading = false;
      // دریافت موفق: شمارش معکوس از ۳۰ ثانیه از نو
      secondsToNextRefresh = autoRefreshSeconds;
      notifyListeners();
    } catch (_) {
      _handleError('خطا در دریافت اطلاعات؛ اتصال اینترنت را بررسی کنید.');
    } finally {
      _isFetching = false;
    }
  }

  /// اعمال اسنپ‌شات منبع ایرانی به فیلدها
  void _applySnapshot(MarketSnapshot snapshot) {
    sourceItems = snapshot.items;
    jdate = snapshot.jdate;
    if (snapshot.feedTimeMs != null) {
      if (feedTimeMs == null || snapshot.feedTimeMs! > feedTimeMs!) {
        feedTimeMs = snapshot.feedTimeMs;
      }
    }
    errorMessage = null;
  }

  /// ترکیب ردیف‌های منبع ایرانی و یاهو:
  /// اگر یاهو برنت داد، برنتِ منبع ایرانی حذف می‌شود تا تکراری نشود؛
  /// وگرنه برنتِ منبع ایرانی به‌عنوان پشتیبان در بخش نفت می‌ماند.
  void _mergeItems() {
    final bool yahooBrent =
        oilItems.any((PriceRow r) => r.title == 'نفت برنت');
    final List<PriceRow> rest = sourceItems
        .where((PriceRow r) =>
            r.group != 'oil' || !(yahooBrent && r.title == 'نفت برنت'))
        .toList();
    items = <PriceRow>[...rest, ...oilItems];
  }

  /// شروع آپدیت خودکار: تیکر ۱ ثانیه‌ای که شمارش معکوس را کم می‌کند
  void startAutoRefresh() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  // ─────────────────────────── Private ───────────────────────────

  /// هر ثانیه: یکی از شمارش معکوس کم کن؛ در صفر رفرش بزن.
  void _tick() {
    if (secondsToNextRefresh > 0) {
      secondsToNextRefresh--;
      notifyListeners();
    }
    if (secondsToNextRefresh == 0) {
      // رفرش پس‌زمینه‌ای بدون اسپینر؛ نتیجه شمارش معکوس را از نو تنظیم می‌کند.
      fetchAll(showLoading: false);
    }
  }

  void _handleError(String message) {
    isLoading = false;
    // اگر داده قبلی موجود است فقط خطا را نشان بده، داده‌ها را پاک نکن
    errorMessage = message;
    // شکست رفرش: زودتر (۱۰ ثانیه بعد) دوباره تلاش کن
    if (secondsToNextRefresh > _retrySeconds) {
      secondsToNextRefresh = _retrySeconds;
    }
    notifyListeners();
  }

  // ───────────────────── چرخه حیات اپلیکیشن ─────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // وقتی اپ به پس‌زمینه می‌رود، تیکر متوقف می‌شود
    if (state == AppLifecycleState.paused) {
      _ticker?.cancel();
      _ticker = null;
    }
    // با بازگشت کاربر، فوراً قیمت تازه گرفته و تیکر از نو راه می‌افتد
    if (state == AppLifecycleState.resumed) {
      fetchAll(showLoading: false);
      startAutoRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _source.dispose();
    _yahoo.dispose();
    super.dispose();
  }
}
