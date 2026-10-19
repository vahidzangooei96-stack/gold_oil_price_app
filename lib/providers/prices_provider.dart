import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/price_models.dart';
import '../services/api_service.dart';
import '../services/yahoo_service.dart';

/// مدیریت State قیمت‌ها با Provider (الگوی ChangeNotifier)
///
/// - دریافت قیمت‌های صفحه اصلی tala.ir در هر ۳۰ ثانیه
/// - شمارش معکوس زنده تا رفرش بعدی (با تیکر ۱ ثانیه‌ای)
/// - در صورت شکست رفرش، به‌جای ۳۰ ثانیه بعد از ۱۰ ثانیه دوباره تلاش می‌کند
/// - درخواست‌ها همیشه با کش‌باستر ارسال می‌شوند تا پاسخ کش‌شده نیاید
/// - توقف/ادامه آپدیت بر اساس چرخه حیات اپ (بهینه‌سازی باتری)
class PricesProvider extends ChangeNotifier with WidgetsBindingObserver {
  PricesProvider({TalaService? talaService, YahooService? yahooService})
      : _api = talaService ?? TalaService(),
        _yahoo = yahooService ?? YahooService() {
    WidgetsBinding.instance.addObserver(this);
  }

  final TalaService _api;
  final YahooService _yahoo;

  /// تیکر ۱ ثانیه‌ای برای شمارش معکوس و اجرای رفرش دوره‌ای
  Timer? _ticker;

  /// جلوگیری از درخواست‌های هم‌زمان و هم‌پوشان
  bool _isFetching = false;

  /// لیست قیمت‌های خام tala.ir (قبل از ادغام با نفت یاهو)
  List<TalaPrice> talaItems = const <TalaPrice>[];

  /// لیست قیمت‌های نفت از یاهو (برنت و WTI)
  List<TalaPrice> oilItems = const <TalaPrice>[];

  /// لیست نهایی ترکیبی برای نمایش (همه گروه‌ها)
  List<TalaPrice> items = const <TalaPrice>[];

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

  /// سن داده بر حسب ثانیه (اختلاف الان با مُهر زمانی سرور)؛
  /// دقیقاً همان چیزی که سایت در ستون «زمان» نشان می‌دهد.
  int? get dataAgeSeconds {
    final int? ms = feedTimeMs;
    if (ms == null) return null;
    final int age =
        DateTime.now().millisecondsSinceEpoch - ms;
    return age < 0 ? 0 : age ~/ 1000;
  }

  /// دریافت قیمت‌ها از هر دو منبع به‌صورت موازی:
  ///  ۱) tala.ir — اونس، نقره، طلا و سکه داخلی (و برنت پشتیبان)
  ///  ۲) Yahoo Finance — برنت و WTI لحظه‌ای
  ///
  /// خطای هر منبع مستقل مهار می‌شود تا شکست یکی، بقیه را از کار نیندازد.
  /// اگر [showLoading] برابر true باشد، اسپینر بارگذاری نمایش داده می‌شود؛
  /// برای آپدیت پس‌زمینه‌ای (تایمر و Pull-to-Refresh) از false استفاده کنید.
  Future<void> fetchAll({bool showLoading = true}) async {
    // جلوگیری از درخواست‌های هم‌زمان و هم‌پوشان
    if (_isFetching) return;
    _isFetching = true;

    if (showLoading) {
      isLoading = true;
      errorMessage = null;
      notifyListeners();
    }

    try {
      final List<Object?> results = await Future.wait(<Future<Object?>>[
        _api
            .fetchPrices()
            .then<Object?>((TalaSnapshot s) => s)
            .catchError((Object e) => e),
        _yahoo
            .fetchOilQuotes()
            .then<Object?>((List<TalaPrice> r) => r)
            .catchError((Object e) => e),
      ]);

      final Object? talaRes = results[0];
      final Object? oilRes = results[1];

      // ── منبع اصلی: tala.ir ──
      if (talaRes is TalaSnapshot) {
        _applyTalaSnapshot(talaRes);
      } else if (items.isEmpty && talaItems.isEmpty) {
        // اولین دریافت هم شکست خورده → خطای کامل
        final String msg = talaRes is ApiException
            ? talaRes.message
            : 'خطا در دریافت اطلاعات؛ اتصال اینترنت را بررسی کنید.';
        _handleError(msg);
        return;
      } else {
        // داده قبلی داریم؛ فقط هشدار بده
        errorMessage = talaRes is ApiException
            ? talaRes.message
            : 'خطا در دریافت اطلاعات؛ اتصال اینترنت را بررسی کنید.';
      }

      // ── منبع نفت: یاهو، با پشتیبانِ برنتِ tala.ir ──
      // اگر یاهو شکست بخورد، برنتِ tala.ir (گروه oil) به‌عنوان پشتیبان
      // در _mergeItems باقی می‌ماند؛ پس فقط وقتی هیچ نفتی نبود خطا می‌دهیم.
      if (oilRes is List<TalaPrice> && oilRes.isNotEmpty) {
        oilItems = oilRes;
        oilError = null;
        // سن داده نفت از خود یاهو
        final int? rmt = _yahoo.lastMarketTimeMs;
        if (rmt != null && (feedTimeMs == null || rmt > feedTimeMs!)) {
          feedTimeMs = rmt;
        }
      } else {
        oilItems = const <TalaPrice>[];
        oilError = talaItems.any((TalaPrice r) => r.group == 'oil')
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

  /// اعمال اسنپ‌شات tala.ir به فیلدها
  void _applyTalaSnapshot(TalaSnapshot snapshot) {
    talaItems = snapshot.items;
    jdate = snapshot.jdate;
    if (snapshot.feedTimeMs != null &&
        (feedTimeMs == null || snapshot.feedTimeMs! > feedTimeMs!)) {
      feedTimeMs = snapshot.feedTimeMs;
    }
    errorMessage = null;
  }

  /// ترکیب ردیف‌های tala و یاهو:
  /// اگر یاهو برنت داد، برنتِ tala حذف می‌شود تا تکراری نشود؛
  /// وگرنه برنتِ tala به‌عنوان پشتیبان در بخش نفت می‌ماند.
  void _mergeItems() {
    final bool yahooBrent =
        oilItems.any((TalaPrice r) => r.title == 'نفت برنت');
    final List<TalaPrice> rest = talaItems
        .where((TalaPrice r) =>
            r.group != 'oil' || !(yahooBrent && r.title == 'نفت برنت'))
        .toList();
    items = <TalaPrice>[...rest, ...oilItems];
  }

  /// شروع آپدیت خودکار: تیکر ۱ ثانیه‌ای که شمارش معکوس را کم می‌کند
  /// و در صفر، رفرش را اجرا می‌کند.
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
      // رفرش پس‌زمینه‌ای بدون اسپینر؛ نتیجه (موفق/ناموفق)
      // شمارش معکوس را از نو تنظیم می‌کند.
      fetchAll(showLoading: false);
    }
  }

  void _handleError(String message) {
    isLoading = false;
    // اگر داده قبلی موجود است فقط خطا را نشان بده، داده‌ها را پاک نکن
    errorMessage = message;
    // شکست رفرش: زودتر (۱۰ ثانیه بعد) دوباره تلاش کن تا داده‌ها
    // هرچه سریع‌تر به جریان تازه برگردند.
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
    _api.dispose();
    _yahoo.dispose();
    super.dispose();
  }
}
