/// مدل نمایشی هر ردیف قیمت دریافتی از منابع داده
///
/// نام عمومی است چون داده ممکن است از هر منبعی بیاید:
/// tala.ir، TGJU، api.tala.ir (رسمی) یا نفت یاهو.
class PriceRow {
  const PriceRow({
    required this.title,
    required this.value,
    required this.unit,
    this.changeText,
    this.isUp,
    this.group = 'global',
  });

  /// عنوان فارسی، مانند «طلای ۱۸ عیار»
  final String title;

  /// مقدار قیمت (با ارقام فارسی)
  final String value;

  /// واحد قیمت، مانند «تومان» یا «دلار برای هر اونس»
  final String unit;

  /// متن درصد تغییر، مانند «۰٫۱۶٪» (null یعنی بدون داده تغییر)
  final String? changeText;

  /// جهت تغییر: true = افزایش، false = کاهش، null = بدون تغییر
  final bool? isUp;

  /// گروه نمایشی برای بخش‌بندی صفحه:
  /// «global» بازار جهانی، «oil» نفت و انرژی، «iran» بازار ایران
  final String group;
}

/// یک اسنپ‌شات کامل قیمت‌ها از هر منبع داده
class MarketSnapshot {
  const MarketSnapshot({required this.items, this.jdate, this.feedTimeMs});

  final List<PriceRow> items;

  /// زمان شمسی آخرین بروزرسانی به‌صورت متن، مانند «18:14 1405/07/27»
  final String? jdate;

  /// مُهر زمانی (میلی‌ثانیه) خودِ داده از سرور؛ برای محاسبه «سن داده»
  final int? feedTimeMs;
}
