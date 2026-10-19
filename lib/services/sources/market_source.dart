import '../../models/price_models.dart';

/// قرارداد مشترک همه منابع داده (APIهای ایرانی و جهانی)
///
/// هر منبع باید بتواند یک [MarketSnapshot] کامل برگرداند؛
/// رابط کاربری از جزئیات هر API بی‌خبر است و فقط منابع را
/// از طریق رجیستری جابه‌جا می‌کند (قابلیت «تغییر منبع داده»).
abstract class MarketSource {
  /// شناسه یکتا برای ذخیره‌سازی و انتخاب، مانند «tala»
  String get id;

  /// نام نمایشی فارسی، مانند «تالا»
  String get displayName;

  /// توضیح فارسی کوتاه برای نمایش در تنظیمات
  String get description;

  /// آیا این منبع برای کار کردن به کلید API نیاز دارد؟
  bool get requiresKey => false;

  /// دریافت اسنپ‌شات قیمت‌ها
  ///
  /// در صورت هر مشکل، [ApiException] با پیام فارسی پرتاب می‌شود.
  Future<MarketSnapshot> fetchSnapshot();

  /// آزادسازی منابع شبکه
  void dispose();
}
