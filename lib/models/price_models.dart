/// مدل نمایشی هر ردیف قیمت دریافتی از tala.ir
class TalaPrice {
  const TalaPrice({
    required this.title,
    required this.value,
    required this.unit,
    this.changeText,
    this.isUp,
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
}

/// یک اسنپ‌شات کامل از قیمت‌های سایت طلا
class TalaSnapshot {
  const TalaSnapshot({required this.items, this.jdate});

  final List<TalaPrice> items;

  /// زمان شمسی آخرین بروزرسانی به‌صورت متن، مانند «18:14 1405/07/27»
  final String? jdate;
}
