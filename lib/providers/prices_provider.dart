import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/price_models.dart';
import '../services/api_service.dart';

/// مدیریت State قیمت‌ها با Provider (الگوی ChangeNotifier)
///
/// وظایف این کلاس:
/// - دریافت قیمت طلا و نفت از [ApiService]
/// - آپدیت خودکار هر ۳۰ ثانیه
/// - نمایش وضعیت بارگذاری و پیام خطای فارسی
/// - توقف/ادامه آپدیت بر اساس چرخه حیات اپ (بهینه‌سازی باتری و دیتا)
class PricesProvider extends ChangeNotifier with WidgetsBindingObserver {
  PricesProvider({ApiService? apiService}) : _api = apiService ?? ApiService() {
    WidgetsBinding.instance.addObserver(this);
  }

  final ApiService _api;
  Timer? _timer;
  bool _isFetching = false;
  String? _lastError;

  /// قیمت انس طلا (XAU/USD)
  PriceData? gold;

  /// قیمت نفت برنت (Brent/USD)
  PriceData? brent;

  /// آیا در حال بارگذاری هستیم؟ (بارگذاری اولیه یا رفرش دستی)
  bool isLoading = true;

  /// پیام خطای فارسی برای نمایش در UI (null یعنی بدون خطا)
  String? errorMessage;

  /// زمان آخرین بروزرسانی موفق (برای نمایش پایین صفحه)
  DateTime? lastUpdated;

  /// فاصله زمانی آپدیت خودکار قیمت‌ها
  static const Duration autoRefreshInterval = Duration(seconds: 30);

  /// دریافت هم‌زمان قیمت طلا و نفت از دو منبع
  ///
  /// اگر [showLoading] برابر true باشد، اسپینر بارگذاری نمایش داده می‌شود؛
  /// برای آپدیت پس‌زمینه‌ای (تایمر و Pull-to-Refresh) از false استفاده کنید
  /// تا پرش ناگهانی UI رخ ندهد.
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
      // هر دو درخواست موازی ارسال می‌شوند؛ شکست یکی، دیگری را خراب نمی‌کند
      final List<double?> results =
          await Future.wait<double?>(<Future<double?>>[
        _safeFetch(_api.fetchGoldPrice),
        _safeFetch(_api.fetchBrentPrice),
      ]);

      final double? goldPrice = results[0];
      final double? brentPrice = results[1];

      if (goldPrice == null && brentPrice == null) {
        // هر دو درخواست شکست خوردند → وضعیت خطا نمایش داده می‌شود
        errorMessage = _lastError ?? 'خطا در دریافت اطلاعات.';
      } else {
        errorMessage = null;
        if (goldPrice != null) gold = _merge(gold, goldPrice);
        if (brentPrice != null) brent = _merge(brent, brentPrice);
        lastUpdated = DateTime.now();
      }

      isLoading = false;
      notifyListeners();
    } finally {
      _isFetching = false;
    }
  }

  /// شروع آپدیت خودکار هر ۳۰ ثانیه
  void startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(
      autoRefreshInterval,
      (_) => fetchAll(showLoading: false),
    );
  }

  // ─────────────────────────── Private ───────────────────────────

  /// ساخت نسخه جدید [PriceData] با حفظ قیمت قبلی (برای نشان افزایش/کاهش)
  PriceData _merge(PriceData? previous, double newPrice) => PriceData(
        price: newPrice,
        previousPrice: previous?.price,
        updatedAt: DateTime.now(),
      );

  /// اجرای یک درخواست با مهار خطا؛ به‌جای پرتاب استثنا null برمی‌گرداند
  /// و پیام خطا را ذخیره می‌کند تا UI قربانی یک منبع خراب نشود.
  Future<double?> _safeFetch(Future<double> Function() request) async {
    try {
      return await request();
    } on ApiException catch (e) {
      _lastError = e.message;
      return null;
    } catch (_) {
      _lastError = 'خطا در دریافت اطلاعات؛ اتصال اینترنت را بررسی کنید.';
      return null;
    }
  }

  // ───────────────────── چرخه حیات اپلیکیشن ─────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // وقتی اپ به پس‌زمینه می‌رود، تایمر متوقف می‌شود
    if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _timer = null;
    }
    // با بازگشت کاربر، فوراً قیمت تازه گرفته و تایمر از نو راه می‌افتد
    if (state == AppLifecycleState.resumed) {
      fetchAll(showLoading: false);
      startAutoRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _api.dispose();
    super.dispose();
  }
}
