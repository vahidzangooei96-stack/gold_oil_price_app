/// مدل نمایشی قیمت هر نماد (انس طلا یا نفت برنت)
///
/// [price]         قیمت لحظه‌ای
/// [previousPrice] قیمت دریافت‌شده قبلی (برای محاسبه جهت تغییر)
/// [updatedAt]     زمان دریافت این قیمت روی دستگاه
class PriceData {
  const PriceData({
    required this.price,
    required this.updatedAt,
    this.previousPrice,
  });

  final double price;
  final double? previousPrice;
  final DateTime updatedAt;

  /// میزان تغییر نسبت به قیمت قبلی؛
  /// اگر قیمت قبلی موجود نباشد `null` است.
  double? get change =>
      previousPrice == null ? null : price - previousPrice!;
}
