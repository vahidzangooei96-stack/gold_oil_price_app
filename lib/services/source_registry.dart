import 'package:http/http.dart' as http;

import 'sources/market_source.dart';
import 'sources/tala_official_source.dart';
import 'sources/tala_source.dart';
import 'sources/tgju_source.dart';

/// گزینه‌های انتخاب منبع داده در تنظیمات اپ
class SourceOption {
  const SourceOption({
    required this.id,
    required this.name,
    required this.description,
    this.requiresKey = false,
  });

  final String id;
  final String name;
  final String description;
  final bool requiresKey;
}

/// رجیستری منابع داده ایرانی قابل انتخاب توسط کاربر
///
///  • «تالا» — پیش‌فرض، بدون کلید
///  • «TGJU» — بدون کلید
///  • «API رسمی تالا» — با کلید API شخصی کاربر (از api.tala.ir)
class SourceRegistry {
  SourceRegistry._();

  /// شناسه منبع پیش‌فرض
  static const String defaultId = 'tala';

  /// فهرست گزینه‌ها به ترتیب نمایش در شیت تنظیمات
  static const List<SourceOption> options = <SourceOption>[
    SourceOption(
      id: 'tala',
      name: 'تالا',
      description: 'tala.ir — سریع‌ترین فید لحظه‌ای طلا، سکه و ارز؛ بدون کلید',
    ),
    SourceOption(
      id: 'tgju',
      name: 'TGJU',
      description: 'tgju.org — پوشش کامل طلا، سکه، ارز، انس و برنت؛ بدون کلید',
    ),
    SourceOption(
      id: 'talaapi',
      name: 'API رسمی تالا',
      description: 'api.tala.ir — وب‌سرویس رسمی با کلید API شخصی شما',
      requiresKey: true,
    ),
  ];

  /// یافتن گزینه بر اساس شناسه (اگر نبود، پیش‌فرض)
  static SourceOption optionOf(String id) {
    for (final SourceOption o in options) {
      if (o.id == id) return o;
    }
    return options.first;
  }

  /// ساخت نمونه منبع داده از روی شناسه؛ برای تست‌ها client قابل تزریق است
  static MarketSource create(
    String id, {
    http.Client? client,
    String? apiKey,
  }) {
    switch (id) {
      case 'tgju':
        return TgjuSource(client: client);
      case 'talaapi':
        return TalaOfficialSource(client: client, apiKey: apiKey ?? '');
      case 'tala':
      default:
        return TalaSource(client: client);
    }
  }
}
