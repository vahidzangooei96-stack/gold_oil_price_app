import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/price_models.dart';
import '../services/api_service.dart';

/// مدیریت State قیمت‌ها با Provider (الگوی ChangeNotifier)
///
/// - دریافت قیمت‌های صفحه اصلی tala.ir
/// - آپدیت خودکار هر ۳۰ ثانیه
/// - نمایش وضعیت بارگذاری و پیام خطای فارسی
/// - توقف/ادامه آپدیت بر اساس چرخه حیات اپ (بهینه‌سازی باتری)
class PricesProvider extends ChangeNotifier with WidgetsBindingObserver {
  PricesProvider({TalaService? talaService}) : _api = talaService ?? TalaService() {
    WidgetsBinding.instance.addObserver(this);
  }

  final TalaService _api;
  Timer? _timer;
  bool _isFetching = false;

  /// لیست قیمت‌ها (null یعنی هنوز دریافت اولیه انجام نشده)
  List<TalaPrice> items = const <TalaPrice>[];

  /// زمان شمسی آخرین بروزرسانی به‌صورت متن (از خود سایت)
  String? jdate;

  /// آیا در حال بارگذاری هستیم؟ (بارگذاری اولیه یا رفرش دستی)
  bool isLoading = true;

  /// پیام خطای فارسی برای نمایش در UI (null یعنی بدون خطا)
  String? errorMessage;

  /// فاصله زمانی آپدیت خودکار قیمت‌ها
  static const Duration autoRefreshInterval = Duration(seconds: 30);

  /// دریافت قیمت‌ها از tala.ir
  ///
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
      final TalaSnapshot snapshot = await _api.fetchPrices();
      items = snapshot.items;
      jdate = snapshot.jdate;
      errorMessage = null;
      isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _handleError(e.message);
    } catch (_) {
      _handleError('خطا در دریافت اطلاعات؛ اتصال اینترنت را بررسی کنید.');
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

  void _handleError(String message) {
    isLoading = false;
    // اگر داده قبلی موجود است فقط خطا را نشان بده، داده‌ها را پاک نکن
    errorMessage = message;
    notifyListeners();
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
