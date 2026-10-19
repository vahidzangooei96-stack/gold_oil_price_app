/// ابزارهای قالب‌بندی اعداد و زمان به سبک فارسی
class Formatters {
  Formatters._();

  static const String _faDigits = '۰۱۲۳۴۵۶۷۸۹';

  /// تبدیل ارقام لاتین به ارقام فارسی
  ///
  /// مثال: 2650.35 → «۲۶۵۰٫۳۵»
  static String toPersianDigits(String input) {
    final StringBuffer buffer = StringBuffer();
    for (final int codeUnit in input.runes) {
      if (codeUnit >= 0x30 && codeUnit <= 0x39) {
        // بازه کد اسکی ارقام 0 تا 9
        buffer.write(_faDigits[codeUnit - 0x30]);
      } else {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  /// قالب‌بندی قیمت با جداکننده هزارگان و اعشار فارسی
  ///
  /// مثال: 2650.35 → «۲٬۶۵۰٫۳۵»
  static String price(double value, {int fractionDigits = 2}) {
    final String fixed = value.toStringAsFixed(fractionDigits);
    final List<String> parts = fixed.split('.');
    final String intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    final String decimals = parts.length > 1 ? parts[1] : '0' * fractionDigits;
    final String latin = '$intPart.$decimals';

    return toPersianDigits(latin)
        .replaceAll(',', '٬') // جداکننده هزارگان فارسی (U+066C)
        .replaceAll('.', '٫'); // جداکننده اعشار فارسی (U+066B)
  }

  /// نمایش ساعت و دقیقه و ثانیه به صورت «۱۴:۰۵:۰۹»
  static String clock(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return toPersianDigits(
      '${two(time.hour)}:${two(time.minute)}:${two(time.second)}',
    );
  }
}
