import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../api_exception.dart';
import '../../models/price_models.dart';
import '../../utils/formatters.dart';
import 'market_source.dart';

/// منبع داده «API رسمی تالا» — api.tala.ir نسخه v1
///
/// این منبع به کلید API اختصاصی نیاز دارد که کاربر خودش از
/// https://api.tala.ir می‌گیرد و در تنظیمات اپ وارد می‌کند.
///
/// جریان کار:
///   ۱) GET /v1/rates?token=...  → فهرست رفرنس‌ها (کلید، عنوان، واحد)
///   ۲) GET /v1/rates/{k1,...,k10}?token=...  → قیمت‌ها (حداکثر ۱۰ کلید در هر فراخوانی)
///
/// ساختار پاسخ به‌صورت تدافعی خوانده می‌شود تا تغییر جزئی سرور
/// اپ را از کار نیندازد.
class TalaOfficialSource extends MarketSource {
  TalaOfficialSource({http.Client? client, this.apiKey = ''})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// کلید API کاربر (از تنظیمات اپ)
  String apiKey;

  @override
  String get id => 'talaapi';

  @override
  String get displayName => 'API رسمی تالا';

  @override
  String get description =>
      'وب‌سرویس رسمی api.tala.ir — برای فعال‌سازی، کلید API خود را از سایت بگیرید و در اپ وارد کنید';

  @override
  bool get requiresKey => true;

  /// حداکثر زمان انتظار برای هر درخواست
  static const Duration _timeout = Duration(seconds: 15);

  /// حداکثر تعداد رفرنسی که قیمت‌شان را می‌گیریم (۴ دسته ۱۰تایی)
  static const int _maxRefs = 40;

  /// حداکثر کلید مجاز در هر فراخوانی (طبق مستندات رسمی)
  static const int _batchSize = 10;

  /// آدرس پایه API
  static const String _baseUrl = 'https://api.tala.ir/v1';

  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/json',
    'Cache-Control': 'no-cache, no-store, must-revalidate',
    'Pragma': 'no-cache',
    'User-Agent': 'GoldPriceApp/1.3',
  };

  /// واژه‌های کلیدی برای انتخاب رفرنس‌های مرتبط با طلا، سکه، ارز و نفت
  static const List<String> _keywords = <String>[
    'gold', 'sekke', 'seke', 'sekee', 'geram', 'mesghal', 'mesg', 'ons',
    'ounce', 'silver', 'oil', 'brent', 'wti', 'dolar', 'dollar', 'eur',
    'currency', 'arz', 'taladasht', 'emami', 'azadi', 'nim', 'rob',
  ];

  @override
  Future<MarketSnapshot> fetchSnapshot() async {
    if (apiKey.trim().isEmpty) {
      throw const ApiException(
        'برای API رسمی تالا باید کلید API را در تنظیمات وارد کنید.',
      );
    }

    // ── مرحله ۱: فهرست رفرنس‌های فعال ──
    final Map<String, dynamic> refsEnvelope =
        await _getJson('$_baseUrl/rates');
    _assertSuccess(refsEnvelope);

    final List<_Ref> refs = _extractRefs(refsEnvelope)
        .where(_isRelevant)
        .take(_maxRefs)
        .toList(growable: false);

    if (refs.isEmpty) {
      throw const ApiException('هیچ رفرنس مناسبی در پاسخ API رسمی تالا نبود.');
    }

    // ── مرحله ۲: دریافت قیمت‌ها به‌صورت دسته‌های ۱۰تایی ──
    final List<PriceRow> rows = <PriceRow>[];
    int? feedTimeMs;
    String? jdate;

    for (int i = 0; i < refs.length; i += _batchSize) {
      final int end =
          (i + _batchSize < refs.length) ? i + _batchSize : refs.length;
      final String keys = refs.sublist(i, end).map((_Ref r) => r.key).join(',');
      final Map<String, dynamic> pricesEnvelope =
          await _getJson('$_baseUrl/rates/$keys');
      _assertSuccess(pricesEnvelope);
      _extractPrices(pricesEnvelope, refs, rows,
          onTimestamp: (int ms) {
            if (feedTimeMs == null || ms > feedTimeMs) feedTimeMs = ms;
          },
          onDateText: (String t) {
            jdate ??= t;
          });
    }

    if (rows.isEmpty) {
      throw const ApiException(
        'قیمتی در پاسخ API رسمی تالا یافت نشد؛ کلید API را بررسی کنید.',
      );
    }

    return MarketSnapshot(items: rows, jdate: jdate, feedTimeMs: feedTimeMs);
  }

  @override
  void dispose() => _client.close();

  // ─────────────────────────── Internal ───────────────────────────

  /// بررسی پاکت پاسخ؛ در صورت success=false پیام فارسی مناسب پرتاب می‌شود
  void _assertSuccess(Map<String, dynamic> envelope) {
    final dynamic success = envelope['success'];
    if (success is bool && !success) {
      throw ApiException(_mapError('${envelope['error'] ?? ''}'));
    }
    final dynamic status = envelope['status'];
    if (status is String && status.toLowerCase() == 'error') {
      throw ApiException(_mapError('${envelope['error'] ?? ''}'));
    }
  }

  /// ترجمه کدهای خطای سرور به پیام فارسی
  String _mapError(String code) {
    switch (code.trim().toUpperCase()) {
      case 'TOKEN_REQUIRED':
        return 'برای API رسمی تالا باید کلید API را در تنظیمات وارد کنید.';
      case 'INVALID_TOKEN':
        return 'کلید API واردشده برای api.tala.ir معتبر نیست.';
      case 'RATE_LIMIT':
        return 'محدودیت تعداد درخواست‌های API رسمی تالا؛ کمی بعد دوباره تلاش کنید.';
      default:
        return 'خطا در دریافت از API رسمی تالا ($code).';
    }
  }

  /// استخراج لیست رفرنس‌ها از پاکت پاسخ (تدافعی)
  List<_Ref> _extractRefs(Map<String, dynamic> envelope) {
    final List<dynamic>? list = _findList(envelope);
    final List<_Ref> refs = <_Ref>[];
    if (list == null) return refs;

    for (final dynamic item in list) {
      if (item is! Map<String, dynamic>) continue;
      final String key = _firstString(item, const <String>[
        'key', 'ref', 'id', 'code', 'symbol', 'name',
      ]);
      if (key.isEmpty) continue;
      final String title = _firstString(item, const <String>[
        'title', 'fa_title', 'name_fa', 'label', 'description', 'fa',
      ]);
      refs.add(_Ref(
        key: key,
        title: title.isEmpty ? key : title,
        unit: _firstString(item, const <String>['unit', 'unit_fa', 'measure']),
      ));
    }
    return refs;
  }

  /// استخراج قیمت‌های دسته فعلی از پاکت پاسخ (تدافعی)
  void _extractPrices(
    Map<String, dynamic> envelope,
    List<_Ref> refs,
    List<PriceRow> rows, {
    required void Function(int ms) onTimestamp,
    required void Function(String text) onDateText,
  }) {
    final Map<String, _Ref> byKey = <String, _Ref>{
      for (final _Ref r in refs) r.key: r,
    };

    // قیمت‌ها ممکن است یک Map مستقیم از کلید→شیء باشند یا داخل یک لیست
    final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
    final dynamic data = envelope['data'] ??
        envelope['rates'] ??
        envelope['result'] ??
        envelope;
    if (data is Map<String, dynamic>) {
      data.forEach((dynamic k, dynamic v) {
        if (v is Map<String, dynamic>) items.add(v);
      });
    } else if (data is List) {
      for (final dynamic v in data) {
        if (v is Map<String, dynamic>) items.add(v);
      }
    }

    for (final Map<String, dynamic> item in items) {
      final String key = _firstString(item, const <String>[
        'key', 'ref', 'id', 'code', 'symbol', 'name',
      ]);
      final _Ref? ref =
          byKey[key] ?? (key.isEmpty ? null : _matchRefLoose(key, refs));
      if (ref == null) continue;

      final double? value = _firstDouble(item, const <String>[
        'price', 'value', 'rate', 'p', 'v', 'last', 'close',
      ]);
      if (value == null || value <= 0) continue;

      // مُهر زمانی اختیاری پاسخ
      final int? ts = _firstInt(item, const <String>[
        'timestamp', 'time', 'updated_at', 'm',
      ]);
      if (ts != null && ts > 1000000000) {
        onTimestamp(ts * 1000);
      }
      final String dateText = _firstString(item, const <String>[
        'jdate', 'date', 't', 'time_fa',
      ]);
      if (dateText.isNotEmpty) onDateText(dateText);

      rows.add(PriceRow(
        title: ref.title,
        value: Formatters.price(value),
        unit: ref.unit.isEmpty ? 'تومان' : ref.unit,
        changeText: _changeText(item),
        isUp: _direction(item),
        group: _groupOf(ref),
      ));
    }
  }

  /// تطبیق نرم کلید وقتی دقیقاً برابر نبود (حروف بزرگ/کوچک یا پیشوند)
  _Ref? _matchRefLoose(String key, List<_Ref> refs) {
    final String k = key.toLowerCase();
    for (final _Ref r in refs) {
      if (r.key.toLowerCase() == k ||
          r.key.toLowerCase().contains(k) ||
          k.contains(r.key.toLowerCase())) {
        return r;
      }
    }
    return null;
  }

  /// گروه‌بندی نمایشی بر اساس کلید/عنوان رفرنس
  String _groupOf(_Ref ref) {
    final String hay = '${ref.key} ${ref.title}'.toLowerCase();
    if (RegExp(r'oil|brent|wti|نفت').hasMatch(hay)) return 'oil';
    if (RegExp(r'ons|ounce|silver|نقره|انس').hasMatch(hay)) return 'global';
    return 'iran';
  }

  /// فیلتر رفرنس‌های مرتبط با موضوع اپ (طلا، سکه، ارز، نفت)
  bool _isRelevant(_Ref ref) {
    final String hay = '${ref.key} ${ref.title}'.toLowerCase();
    return _keywords.any(hay.contains);
  }

  /// متن درصد تغییر از فیلدهای احتمالی
  String? _changeText(Map<String, dynamic> item) {
    final double? pct = _firstDouble(item, const <String>[
      'change_percent', 'percent', 'dp', 'changePercent',
    ]);
    if (pct == null || pct == 0) return null;
    return '${Formatters.toPersianDigits(pct.abs().toStringAsFixed(2))}٪';
  }

  /// جهت تغییر از فیلدهای احتمالی
  bool? _direction(Map<String, dynamic> item) {
    final String dt = _firstString(item, const <String>[
      'direction', 'trend', 'dt',
    ]).toLowerCase();
    if (dt.contains('up') || dt.contains('high')) return true;
    if (dt.contains('down') || dt.contains('low')) return false;
    final double? change = _firstDouble(item, const <String>[
      'change', 'd', 'diff',
    ]);
    if (change == null || change == 0) return null;
    return change > 0;
  }

  /// جستجوی لیست داخل پاکت (data/rates/result/…)
  List<dynamic>? _findList(Map<String, dynamic> envelope) {
    for (final String k in const <String>['data', 'rates', 'result', 'refs']) {
      final dynamic v = envelope[k];
      if (v is List) return v;
    }
    for (final dynamic v in envelope.values) {
      if (v is List) return v;
    }
    return null;
  }

  String _firstString(Map<String, dynamic> item, List<String> keys) {
    for (final String k in keys) {
      final dynamic v = item[k];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return '';
  }

  double? _firstDouble(Map<String, dynamic> item, List<String> keys) {
    for (final String k in keys) {
      final dynamic v = item[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final double? d =
            double.tryParse(v.replaceAll(',', '').replaceAll('٬', '').trim());
        if (d != null) return d;
      }
    }
    return null;
  }

  int? _firstInt(Map<String, dynamic> item, List<String> keys) {
    for (final String k in keys) {
      final dynamic v = item[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim());
    }
    return null;
  }

  /// دریافت و رمزگشایی پاسخ JSON با خطاهای فارسی
  Future<Map<String, dynamic>> _getJson(String path) async {
    final int bust = DateTime.now().millisecondsSinceEpoch;
    final Uri uri = Uri.parse('$path?token=${Uri.encodeComponent(apiKey.trim())}&_=$bust');
    try {
      final http.Response response =
          await _client.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const ApiException('کلید API واردشده برای api.tala.ir معتبر نیست.');
      }
      if (response.statusCode != 200) {
        throw ApiException('سرور API تالا با کد ${response.statusCode} پاسخ داد.');
      }

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;

      throw const ApiException('ساختار پاسخ API تالا قابل خواندن نبود.');
    } on SocketException {
      throw const ApiException('اتصال اینترنت برقرار نیست.');
    } on TimeoutException {
      throw const ApiException('پاسخی از api.tala.ir دریافت نشد (مهلت تمام شد).');
    } on FormatException {
      throw const ApiException('پاسخ API تالا معتبر نبود.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('خطای نامشخص در دریافت از API رسمی تالا.');
    }
  }
}

/// یک رفرنس (نماد) فعال در API رسمی تالا
class _Ref {
  const _Ref({required this.key, required this.title, required this.unit});

  final String key;
  final String title;
  final String unit;
}
