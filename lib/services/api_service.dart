import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/price_models.dart';
import '../utils/formatters.dart';

/// خطای سطح اپلیکیشن همراه با پیام فارسی، آماده برای نمایش به کاربر
class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// پیکربندی یک ردیف قیمت: از کدام بخش و کلید JSON بخوانیم و چه نامی بگذاریم
class PriceRowConfig {
  const PriceRowConfig(this.section, this.key, this.title, this.unit);

  final String section;
  final String key;
  final String title;
  final String unit;
}

/// سرویس دریافت قیمت‌ها از سایت طلا (tala.ir)
///
/// منبع داده، همان endpoint رسمی AJAX صفحه اصلی سایت است:
/// https://www.tala.ir/ajax/price
/// که خود صفحه اصلی tala.ir نیز قیمت‌هایش را از همین‌جا پر می‌کند.
class TalaService {
  TalaService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// حداکثر زمان انتظار برای درخواست
  static const Duration _timeout = Duration(seconds: 15);

  /// آدرس endpoint قیمت‌ها (بدون پارامتر؛ کش‌باستر در هر درخواست اضافه می‌شود)
  static const String _priceUrl = 'https://www.tala.ir/ajax/price';

  /// هدرهای شبیه مرورگر؛ سرور درخواست AJAX بدون این هدرها را رد می‌کند.
  /// هدرهای no-cache تضمین می‌کنند هیچ پروکسی/ISP‌ای پاسخ کش‌شده ندهد.
  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'X-Requested-With': 'XMLHttpRequest',
    'Referer': 'https://www.tala.ir/',
    'Cache-Control': 'no-cache, no-store, must-revalidate',
    'Pragma': 'no-cache',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 GoldPriceApp/1.2',
  };

  /// ساخت آدرس درخواست با پارامتر کش‌باستر متغیر در هر لحظه؛
  /// این کار مطمئن می‌شود همیشه تازه‌ترین داده از سرور اصلی tala.ir
  /// دریافت می‌شود، نه پاسخ کش‌شده‌ی مسیرهای میانی.
  static Uri _freshUri() {
    final int bust = DateTime.now().millisecondsSinceEpoch;
    return Uri.parse('$_priceUrl?_=$bust');
  }

  /// همان قیمت‌هایی که در صفحه اصلی tala.ir نمایش داده می‌شوند
  static const List<PriceRowConfig> _rows = <PriceRowConfig>[
    PriceRowConfig('gold', 'gold_ounce', 'اونس طلا', 'دلار برای هر اونس'),
    PriceRowConfig('gold', 'gold_bazaruser', 'مثقال ۱۷', 'تومان'),
    PriceRowConfig('gold', 'gold_18k', 'طلای ۱۸ عیار', 'تومان'),
    PriceRowConfig('gold', 'gold_24k', 'طلای ۲۴ عیار', 'تومان'),
    PriceRowConfig('sekke', 'sekke-jad', 'سکه امامی', 'تومان'),
    PriceRowConfig('sekke', 'sekke-nim', 'نیم سکه', 'تومان'),
    PriceRowConfig('sekke', 'sekke-rob', 'ربع سکه', 'تومان'),
    PriceRowConfig('sekke', 'sekke-grm', 'سکه گرمی', 'تومان'),
    PriceRowConfig('sekke', 'sekke-mazane', 'ارزش طلای سکه', 'تومان'),
    PriceRowConfig('other', 'other_oil', 'نفت برنت', 'دلار برای هر بشکه'),
    PriceRowConfig('other', 'other_silver', 'نقره جهانی', 'دلار برای هر اونس'),
  ];

  /// دریافت همه قیمت‌ها در یک درخواست
  Future<TalaSnapshot> fetchPrices() async {
    final Map<String, dynamic> data = await _getJson(_freshUri());

    final List<TalaPrice> rows = <TalaPrice>[];
    String? jdate;
    int? feedTimeMs; // بزرگ‌ترین m یعنی تازه‌ترین مُهر زمانی داده سرور

    for (final PriceRowConfig cfg in _rows) {
      final dynamic section = data[cfg.section];
      if (section is! Map<String, dynamic>) continue;
      final dynamic item = section[cfg.key];
      if (item is! Map<String, dynamic>) continue;

      jdate ??= (item['jdate'] as String?);
      final int? m = int.tryParse('${item['m'] ?? ''}');
      if (m != null && m > 1000000000) {
        // فیلد m بر حسب ثانیه است؛ به میلی‌ثانیه تبدیل می‌کنیم
        final int ms = m * 1000;
        feedTimeMs = (feedTimeMs == null || ms > feedTimeMs) ? ms : feedTimeMs;
      }

      rows.add(TalaPrice(
        title: cfg.title,
        value: _formatValue(item),
        unit: cfg.unit,
        changeText: _changePercent(item['d'] as String?),
        isUp: _direction(item['d'] as String?),
      ));
    }

    if (rows.isEmpty) {
      throw const ApiException('قیمتی در پاسخ سرور یافت نشد.');
    }

    return TalaSnapshot(
      items: rows,
      jdate: jdate,
      feedTimeMs: feedTimeMs,
    );
  }

  /// آزادسازی منابع شبکه
  void dispose() => _client.close();

  // ─────────────────────────── Internal ───────────────────────────

  /// دریافت و رمزگشایی پاسخ JSON
  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    try {
      final http.Response response =
          await _client.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode != 200) {
        throw ApiException('سرور با کد ${response.statusCode} پاسخ داد.');
      }

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;

      throw const ApiException('ساختار پاسخ سرور قابل خواندن نبود.');
    } on SocketException {
      throw const ApiException('اتصال اینترنت برقرار نیست.');
    } on TimeoutException {
      throw const ApiException('پاسخی از tala.ir دریافت نشد (مهلت تمام شد).');
    } on FormatException {
      throw const ApiException('پاسخ سرور معتبر نبود.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('خطای نامشخص در دریافت اطلاعات.');
    }
  }

  /// قالب‌بندی مقدار قیمت؛ اگر عدد قابل خواندن باشد با قالب فارسی زیبا
  /// نمایش داده می‌شود، وگرنه همان متن سایت (v_fa) برمی‌گردد.
  ///
  /// مقدار صفر یا منفی (ناشی از بسته بودن بازار یا ناسازگاری لحظه‌ای
  /// فید سرور) به‌جای نمایش عدد گمراه‌کننده، با «—» نمایش داده می‌شود.
  String _formatValue(Map<String, dynamic> item) {
    final String? raw = (item['v'] ?? item['v_fa'])?.toString();
    if (raw == null || raw.isEmpty) return '—';
    final String cleaned = raw.replaceAll(',', '').trim();
    final double? num = double.tryParse(cleaned);
    if (num == null) return raw; // مقدار غیرعددی: همان متن اصلی
    if (num <= 0) return '—'; // قیمت صفر/منفی معنا ندارد
    return Formatters.price(num);
  }

  /// استخراج درصد تغییر از متن d سایت، مانند «-7.06 (0.16%)» → «۰.۱۶٪»
  String? _changePercent(String? d) {
    if (d == null || d.trim().isEmpty) return null;
    final Match? m = RegExp(r'\(([^)]+)\)').firstMatch(d);
    final String? pct = m?.group(1);
    if (pct == null || pct.trim().isEmpty) return null;
    return Formatters.toPersianDigits(pct.trim());
  }

  /// تشخیص جهت تغییر از علامتِ ابتدای متن d
  bool? _direction(String? d) {
    if (d == null || d.trim().isEmpty) return null;
    final Match? m = RegExp(r'^\s*(-?)\s*([\d,\.]+)').firstMatch(d);
    if (m == null) return null;
    final double? num =
        double.tryParse((m.group(2) ?? '0').replaceAll(',', ''));
    if (num == null || num == 0) return null;
    return (m.group(1) ?? '').isEmpty;
  }
}
