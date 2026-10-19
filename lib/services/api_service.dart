import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// خطای سطح اپلیکیشن همراه با پیام فارسی، آماده برای نمایش به کاربر
class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// سرویس دریافت قیمت‌ها از دو API رایگان (بدون نیاز به کلید)
///
/// - انس طلا:    https://xaus.com/api/v1/spot             → فیلد spot_usd_oz
/// - نفت برنت:  https://americasoilwatch.com/api/v1/brent → فیلد priceUsd
class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// حداکثر زمان انتظار برای هر درخواست
  static const Duration _timeout = Duration(seconds: 15);

  static const Uri _goldUri = Uri.parse('https://xaus.com/api/v1/spot');
  static const Uri _brentUri =
      Uri.parse('https://americasoilwatch.com/api/v1/brent');

  /// هدر User-Agent واقعی‌نما؛ بعضی سرورها (پشت Cloudflare) درخواست‌های
  /// بدون UA مرورگر را رد می‌کنند.
  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/json',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 GoldOilPriceApp/1.0',
  };

  /// قیمت انس طلا (XAU/USD) بر حسب دلار برای هر اونس
  Future<double> fetchGoldPrice() async {
    final Map<String, dynamic> data = await _getJson(_goldUri);
    final dynamic raw = _resolve(data, const <String>[
      'spot_usd_oz', // فیلد رسمی مستندشده xaus.com
      'spotUsdOz', // حالت جایگزین camelCase
      'price',
    ]);
    return _toDouble(raw, 'spot_usd_oz');
  }

  /// قیمت نفت برنت بر حسب دلار برای هر بشکه
  Future<double> fetchBrentPrice() async {
    final Map<String, dynamic> data = await _getJson(_brentUri);
    final dynamic raw = _resolve(data, const <String>[
      'priceUsd', // فیلد رسمی مستندشده americasoilwatch.com
      'price_usd', // حالت جایگزین snake_case
      'price',
    ]);
    return _toDouble(raw, 'priceUsd');
  }

  /// آزادسازی منابع شبکه
  void dispose() => _client.close();

  // ─────────────────────────── Internal ───────────────────────────

  /// دریافت و رمزگشایی پاسخ JSON از سرور
  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    try {
      final http.Response response =
          await _client.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode != 200) {
        throw ApiException('سرور با کد ${response.statusCode} پاسخ داد.');
      }

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is Map<String, dynamic>) {
        // بعضی APIها داده اصلی را داخل یک فیلد تودرتو برمی‌گردانند
        final dynamic inner = decoded['data'];
        if (decoded.length == 1 && inner is Map<String, dynamic>) {
          return inner;
        }
        return decoded;
      }

      // اگر پاسخ آرایه‌ای از آبجکت‌ها بود، عنصر اول را در نظر بگیر
      if (decoded is List &&
          decoded.isNotEmpty &&
          decoded.first is Map<String, dynamic>) {
        return decoded.first as Map<String, dynamic>;
      }

      throw const ApiException('ساختار پاسخ سرور قابل خواندن نبود.');
    } on SocketException {
      throw const ApiException('اتصال اینترنت برقرار نیست.');
    } on TimeoutException {
      throw const ApiException('پاسخی از سرور دریافت نشد (مهلت تمام شد).');
    } on FormatException {
      throw const ApiException('پاسخ سرور معتبر نبود.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('خطای نامشخص در دریافت اطلاعات.');
    }
  }

  /// جست‌وجوی فیلد قیمت در سطح اول و سپس در آبجکت‌های تودرتوی رایج
  dynamic _resolve(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      if (data[key] != null) return data[key];
    }
    for (final String container in const <String>['data', 'result', 'payload']) {
      final dynamic inner = data[container];
      if (inner is Map<String, dynamic>) {
        for (final String key in keys) {
          if (inner[key] != null) return inner[key];
        }
      }
    }
    throw ApiException('فیلد «${keys.first}» در پاسخ سرور یافت نشد.');
  }

  /// تبدیل مقدار خام به double با تحمل نوع رشته‌ای
  double _toDouble(dynamic raw, String field) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final double? parsed = double.tryParse(raw.replaceAll(',', ''));
      if (parsed != null) return parsed;
    }
    throw ApiException('مقدار فیلد «$field» عدد معتبری نیست.');
  }
}
