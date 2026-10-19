import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../api_exception.dart';
import '../../models/price_models.dart';
import '../../utils/formatters.dart';
import 'market_source.dart';

/// پیکربندی یک ردیف قیمت: از کدام بخش و کلید JSON بخوانیم و چه نامی بگذاریم
class PriceRowConfig {
  const PriceRowConfig(
    this.section,
    this.key,
    this.title,
    this.unit, {
    this.group = 'global',
  });

  final String section;
  final String key;
  final String title;
  final String unit;

  /// گروه نمایشی: «global»، «oil» یا «iran»
  final String group;
}

/// منبع داده «تالا» — endpoint رسمی AJAX صفحه اصلی tala.ir
///
/// همان چیزی که خود صفحه اصلی tala.ir قیمت‌هایش را از آن پر می‌کند:
/// https://www.tala.ir/ajax/price  — بدون نیاز به کلید
class TalaSource extends MarketSource {
  TalaSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get id => 'tala';

  @override
  String get displayName => 'تالا';

  @override
  String get description =>
      'قیمت‌های لحظه‌ای tala.ir — طلا، سکه، ارز و فلزات؛ سریع و بدون کلید';

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
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 GoldPriceApp/1.3',
  };

  /// ساخت آدرس درخواست با پارامتر کش‌باستر متغیر در هر لحظه؛
  /// تضمین می‌شود همیشه تازه‌ترین داده از سرور اصلی دریافت شود.
  static Uri _freshUri() {
    final int bust = DateTime.now().millisecondsSinceEpoch;
    return Uri.parse('$_priceUrl?_=$bust');
  }

  /// قیمت‌های صفحه اصلی tala.ir؛ گروه‌بندی‌شده برای نمایش بخشی:
  /// بازار جهانی ← بازار ایران ← نفت (پشتیبان برنت وقتی یاهو در دسترس نباشد)
  static const List<PriceRowConfig> _rows = <PriceRowConfig>[
    PriceRowConfig('gold', 'gold_ounce', 'اونس جهانی طلا', 'دلار برای هر اونس',
        group: 'global'),
    PriceRowConfig('other', 'other_silver', 'نقره جهانی', 'دلار برای هر اونس',
        group: 'global'),
    PriceRowConfig('gold', 'gold_bazaruser', 'مثقال طلا', 'تومان',
        group: 'iran'),
    PriceRowConfig('gold', 'gold_18k', 'طلای ۱۸ عیار', 'تومان برای هر گرم',
        group: 'iran'),
    PriceRowConfig('gold', 'gold_24k', 'طلای ۲۴ عیار', 'تومان برای هر گرم',
        group: 'iran'),
    PriceRowConfig('sekke', 'sekke-jad', 'سکه امامی', 'تومان', group: 'iran'),
    PriceRowConfig('sekke', 'sekke-nim', 'نیم سکه', 'تومان', group: 'iran'),
    PriceRowConfig('sekke', 'sekke-rob', 'ربع سکه', 'تومان', group: 'iran'),
    PriceRowConfig('sekke', 'sekke-grm', 'سکه گرمی', 'تومان', group: 'iran'),
    PriceRowConfig('other', 'other_oil', 'نفت برنت', 'دلار برای هر بشکه',
        group: 'oil'),
  ];

  @override
  Future<MarketSnapshot> fetchSnapshot() async {
    final Map<String, dynamic> data = await _getJson(_freshUri());

    final List<PriceRow> rows = <PriceRow>[];
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

      rows.add(PriceRow(
        title: cfg.title,
        value: _formatValue(item),
        unit: cfg.unit,
        changeText: _changePercent(item['d'] as String?),
        isUp: _direction(item['d'] as String?),
        group: cfg.group,
      ));
    }

    if (rows.isEmpty) {
      throw const ApiException('قیمتی در پاسخ سرور یافت نشد.');
    }

    return MarketSnapshot(
      items: rows,
      jdate: jdate,
      feedTimeMs: feedTimeMs,
    );
  }

  @override
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
