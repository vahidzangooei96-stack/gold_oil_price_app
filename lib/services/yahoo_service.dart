import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/price_models.dart';
import '../utils/formatters.dart';
import 'api_exception.dart';

/// سرویس قیمت لحظه‌ای نفت از Yahoo Finance — بدون نیاز به کلید API
///
/// از endpoint عمومی نمودار استفاده می‌کند که نمادهای آتی نفت را می‌دهد:
///   WTI   → https://query1.finance.yahoo.com/v8/finance/chart/CL=F
///   برنت  → https://query1.finance.yahoo.com/v8/finance/chart/BZ=F
///
/// این منبع، نفت WTI را (که در منابع ایرانی نیست) تأمین می‌کند و
/// برنت را هم با تازگی بالاتر به‌روزرسانی می‌کند.
class YahooService {
  YahooService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// حداکثر زمان انتظار برای هر درخواست
  static const Duration _timeout = Duration(seconds: 12);

  /// هدرهای شبیه مرورگر
  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/json',
    'Cache-Control': 'no-cache',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
  };

  /// دریافت برنت و WTI به‌صورت موازی؛ خطای هر نماد مستقل است و
  /// اگر هر دو شکست بخورند، ApiException پرتاب می‌شود.
  Future<List<PriceRow>> fetchOilQuotes() async {
    final List<Object?> results = await Future.wait(<Future<Object?>>[
      _fetchSymbol('CL%3DF', 'نفت WTI')
          .then<Object?>((PriceRow v) => v)
          .catchError((Object _) => null),
      _fetchSymbol('BZ%3DF', 'نفت برنت')
          .then<Object?>((PriceRow v) => v)
          .catchError((Object _) => null),
    ]);

    final List<PriceRow> rows = <PriceRow>[];
    for (final Object? r in results) {
      if (r is PriceRow) rows.add(r);
    }

    if (rows.isEmpty) {
      throw const ApiException('قیمت نفت جهانی در دسترس نیست.');
    }

    // برنت همیشه اول نمایش داده شود
    rows.sort(
      (PriceRow a, PriceRow b) =>
          (a.title == 'نفت برنت' ? 0 : 1) - (b.title == 'نفت برنت' ? 0 : 1),
    );
    return rows;
  }

  /// زمان مُهر آخرین قیمت از خود یاهو (میلی‌ثانیه)؛ null یعنی موجود نبود
  int? lastMarketTimeMs;

  /// آزادسازی منابع شبکه
  void dispose() => _client.close();

  // ─────────────────────────── Internal ───────────────────────────

  /// دریافت قیمت یک نماد آتی نفت و تبدیل آن به ردیف نمایشی
  Future<PriceRow> _fetchSymbol(String symbol, String title) async {
    // کش‌باستر تا هیچ پاسخ کش‌شده‌ای برنگردد
    final int bust = DateTime.now().millisecondsSinceEpoch;
    final Uri uri = Uri.parse(
      'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?_=$bust',
    );

    final http.Response response =
        await _client.get(uri, headers: _headers).timeout(_timeout);

    if (response.statusCode != 200) {
      throw ApiException('سرور یاهو با کد ${response.statusCode} پاسخ داد.');
    }

    final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('پاسخ سرور یاهو معتبر نبود.');
    }

    final dynamic chartResult = decoded['chart']?['result'];
    if (chartResult is! List || chartResult.isEmpty) {
      throw const ApiException('داده نمودار یافت نشد.');
    }
    final dynamic result0 = chartResult.first;
    if (result0 is! Map<String, dynamic>) {
      throw const ApiException('ساختار پاسخ یاهو عوض شده است.');
    }

    final dynamic meta = result0['meta'];
    if (meta is! Map<String, dynamic>) {
      throw const ApiException('متادیتای قیمت یافت نشد.');
    }

    final dynamic price = meta['regularMarketPrice'];
    if (price is! num || price <= 0) {
      throw const ApiException('قیمت معتبری در پاسخ نبود.');
    }

    // زمان آخرین به‌روزرسانی بازار (ثانیه) — برای محاسبه سن داده
    final dynamic marketTime = meta['regularMarketTime'];
    if (marketTime is num && marketTime > 1000000000) {
      lastMarketTimeMs = (marketTime * 1000).toInt();
    }

    // درصد تغییر از خود سرور یاهو
    String? changeText;
    bool? isUp;
    final dynamic pct = meta['regularMarketChangePercent'];
    if (pct is num) {
      final double p = pct.toDouble();
      final String abs =
          Formatters.toPersianDigits(p.abs().toStringAsFixed(2));
      changeText = '$abs٪';
      isUp = p >= 0;
    }

    return PriceRow(
      title: title,
      value: Formatters.price(price.toDouble()),
      unit: 'دلار برای هر بشکه',
      changeText: changeText,
      isUp: isUp,
      group: 'oil',
    );
  }
}
