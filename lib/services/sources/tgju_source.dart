import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../api_exception.dart';
import '../../models/price_models.dart';
import '../../utils/formatters.dart';
import 'market_source.dart';

/// منبع داده «TGJU» — بزرگ‌ترین سامانه قیمت ایران (tgju.org)
///
/// endpoint عمومی و بدون کلید:
/// https://call.tgju.org/ajax.json
///
/// نکته واحدها:
///  • قیمت‌های داخلی (طلا، سکه، ارز) در پاسخ به «ریال» هستند → برای
///    هم‌خوانی با منبع تالا، بر ۱۰ تقسیم و به «تومان» نمایش داده می‌شوند.
///  • قیمت‌های جهانی (انس طلا، نقره، برنت) به «دلار» و بدون تبدیل‌اند.
class TgjuSource extends MarketSource {
  TgjuSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get id => 'tgju';

  @override
  String get displayName => 'TGJU';

  @override
  String get description =>
      'سامانه قیمت tgju.org — طلا، سکه، ارز، انس و برنت؛ پوشش گسترده و بدون کلید';

  /// حداکثر زمان انتظار برای درخواست
  static const Duration _timeout = Duration(seconds: 15);

  /// آدرس endpoint قیمت‌ها (کش‌باستر در هر درخواست اضافه می‌شود)
  static const String _priceUrl = 'https://call.tgju.org/ajax.json';

  /// فاصله زمانی ایران با UTC (۳ ساعت و ۳۰ دقیقه) برای تبدیل ts
  static const int _iranOffsetMs = 3 * 3600 * 1000 + 30 * 60 * 1000;

  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/json, text/plain, */*',
    'Referer': 'https://www.tgju.org/',
    'Cache-Control': 'no-cache, no-store, must-revalidate',
    'Pragma': 'no-cache',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
  };

  /// پیکربندی ردیف‌ها: کلید tgju ← عنوان فارسی + واحد + گروه + تبدیل ریال→تومان
  static const List<_TgjuRow> _rows = <_TgjuRow>[
    _TgjuRow('ons', 'اونس جهانی طلا', 'دلار برای هر اونس', 'global'),
    _TgjuRow('silver', 'نقره جهانی', 'دلار برای هر اونس', 'global'),
    _TgjuRow('geram18', 'طلای ۱۸ عیار', 'تومان برای هر گرم', 'iran'),
    _TgjuRow('geram24', 'طلای ۲۴ عیار', 'تومان برای هر گرم', 'iran'),
    _TgjuRow('mesghal', 'مثقال طلا', 'تومان', 'iran'),
    _TgjuRow('sekee', 'سکه امامی', 'تومان', 'iran'),
    _TgjuRow('nim', 'نیم سکه', 'تومان', 'iran'),
    _TgjuRow('rob', 'ربع سکه', 'تومان', 'iran'),
    _TgjuRow('gerami', 'سکه گرمی', 'تومان', 'iran'),
    _TgjuRow('price_dollar_rl', 'دلار آمریکا', 'تومان', 'iran'),
    _TgjuRow('price_eur', 'یورو', 'تومان', 'iran'),
    _TgjuRow('oil_brent', 'نفت برنت', 'دلار برای هر بشکه', 'oil'),
  ];

  @override
  Future<MarketSnapshot> fetchSnapshot() async {
    final int bust = DateTime.now().millisecondsSinceEpoch;
    final Map<String, dynamic> data =
        await _getJson(Uri.parse('$_priceUrl?_=$bust'));

    final dynamic current = data['current'];
    if (current is! Map<String, dynamic>) {
      throw const ApiException('ساختار پاسخ TGJU قابل خواندن نبود.');
    }

    final List<PriceRow> rows = <PriceRow>[];
    String? jdate;
    int? feedTimeMs;

    for (final _TgjuRow cfg in _rows) {
      final dynamic item = current[cfg.key];
      if (item is! Map<String, dynamic>) continue;

      final double? value = _parseNumber(item['p']);
      if (value == null || value <= 0) continue; // داده نامعتبر: رد بشود

      // تبدیل ریال به تومان برای قیمت‌های داخلی
      final double displayValue =
          cfg.isToman ? value / 10 : value;

      // مُهر زمانی رشته‌ای سرور، مانند 2026-10-19 01:43:01 (به وقت ایران)
      final int? ms = _parseIranTimestamp('${item['ts'] ?? ''}');
      if (ms != null && (feedTimeMs == null || ms > feedTimeMs)) {
        feedTimeMs = ms;
      }

      // متن زمان شمسی/ساعتی خود سرور برای ردیف تازه‌تر
      final String? t = (item['t'] as String?)?.trim();
      if (t != null && t.isNotEmpty &&
          (jdate == null || (ms != null && ms == feedTimeMs))) {
        jdate ??= t;
      }

      rows.add(PriceRow(
        title: cfg.title,
        value: Formatters.price(displayValue),
        unit: cfg.unit,
        changeText: _changeText(item),
        isUp: _direction(item),
        group: cfg.group,
      ));
    }

    if (rows.isEmpty) {
      throw const ApiException('قیمتی در پاسخ TGJU یافت نشد.');
    }

    return MarketSnapshot(items: rows, jdate: jdate, feedTimeMs: feedTimeMs);
  }

  @override
  void dispose() => _client.close();

  // ─────────────────────────── Internal ───────────────────────────

  /// دریافت و رمزگشایی پاسخ JSON با خطاهای فارسی
  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    try {
      final http.Response response =
          await _client.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode != 200) {
        throw ApiException('سرور TGJU با کد ${response.statusCode} پاسخ داد.');
      }

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;

      throw const ApiException('ساختار پاسخ TGJU قابل خواندن نبود.');
    } on SocketException {
      throw const ApiException('اتصال اینترنت برقرار نیست.');
    } on TimeoutException {
      throw const ApiException('پاسخی از TGJU دریافت نشد (مهلت تمام شد).');
    } on FormatException {
      throw const ApiException('پاسخ TGJU معتبر نبود.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('خطای نامشخص در دریافت اطلاعات.');
    }
  }

  /// «۲۶۱٬۷۷۸٬۰۰۰» یا «4142.08» را به عدد تبدیل می‌کند
  double? _parseNumber(dynamic raw) {
    if (raw == null) return null;
    final String cleaned =
        raw.toString().replaceAll(',', '').replaceAll('٬', '').trim();
    return double.tryParse(cleaned);
  }

  /// تغییر درصد از فیلد dp؛ مثل «0.93» → «۰٫۹۳٪»
  String? _changeText(Map<String, dynamic> item) {
    final double? dp = _parseNumber(item['dp']);
    if (dp == null || dp == 0) return null;
    return '${Formatters.toPersianDigits(dp.toStringAsFixed(2))}٪';
  }

  /// جهت تغییر از فیلد dt: high = صعودی، low = نزولی
  bool? _direction(Map<String, dynamic> item) {
    final String dt = '${item['dt'] ?? ''}'.trim().toLowerCase();
    if (dt == 'high') return true;
    if (dt == 'low') return false;
    return null;
  }

  /// تبدیل «2026-10-19 01:43:01» (به وقت ایران) به میلی‌ثانیه اپوک
  int? _parseIranTimestamp(String raw) {
    final RegExpMatch? m = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})',
    ).firstMatch(raw.trim());
    if (m == null) return null;
    try {
      final int msUtc = DateTime.utc(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
        int.parse(m.group(6)!),
      ).millisecondsSinceEpoch;
      return msUtc - _iranOffsetMs;
    } on FormatException {
      return null;
    }
  }
}

/// پیکربندی یک ردیف TGJU
class _TgjuRow {
  const _TgjuRow(this.key, this.title, this.unit, this.group)
      : isToman = group == 'iran';

  final String key;
  final String title;
  final String unit;
  final String group;

  /// قیمت‌های داخلی tgju ریال است؛ برای نمایش تومان باید بر ۱۰ تقسیم شود
  final bool isToman;
}
