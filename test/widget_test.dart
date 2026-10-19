import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gold_oil_price/main.dart';
import 'package:gold_oil_price/models/price_models.dart';
import 'package:gold_oil_price/providers/prices_provider.dart';
import 'package:gold_oil_price/providers/theme_provider.dart';
import 'package:gold_oil_price/services/sources/tala_source.dart';
import 'package:gold_oil_price/services/sources/tgju_source.dart';
import 'package:gold_oil_price/services/yahoo_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// منبع جعلی تالا بدون تماس با شبکه برای تست
///
/// feedTimeMs برابر «الان» داده می‌شود تا محاسبه «سن داده» هم تست شود.
class FakeTalaSource extends TalaSource {
  @override
  Future<MarketSnapshot> fetchSnapshot() async => MarketSnapshot(
        items: <PriceRow>[
          const PriceRow(
            title: 'اونس جهانی طلا',
            value: '۲٬۶۵۰٫۳۵',
            unit: 'دلار برای هر اونس',
            changeText: '۰٫۵٪',
            isUp: true,
            group: 'global',
          ),
          const PriceRow(
            title: 'طلای ۱۸ عیار',
            value: '۳٬۴۷۷٬۰۹۰',
            unit: 'تومان برای هر گرم',
            changeText: '۰٫۵٪',
            isUp: true,
            group: 'iran',
          ),
          const PriceRow(
            title: 'سکه امامی',
            value: '—',
            unit: 'تومان',
            group: 'iran',
          ),
        ],
        jdate: '18:14 1405/07/27',
        feedTimeMs: DateTime.now().millisecondsSinceEpoch,
      );
}

/// سرویس جعلی یاهو بدون تماس با شبکه برای تست
class FakeYahooService extends YahooService {
  @override
  Future<List<PriceRow>> fetchOilQuotes() async => const <PriceRow>[
        PriceRow(
          title: 'نفت برنت',
          value: '۱۰۹٫۳۸',
          unit: 'دلار برای هر بشکه',
          changeText: '۱٫۵۷٪',
          isUp: true,
          group: 'oil',
        ),
        PriceRow(
          title: 'نفت WTI',
          value: '۹۸٫۴۰',
          unit: 'دلار برای هر بشکه',
          changeText: '۰٫۶۳٪',
          isUp: false,
          group: 'oil',
        ),
      ];
}

void main() {
  testWidgets('صفحه اصلی با داده جعلی رندر می‌شود (بدون تماس با شبکه)',
      (WidgetTester tester) async {
    final PricesProvider prices = PricesProvider(
      source: FakeTalaSource(),
      yahooService: FakeYahooService(),
    );

    // شروع دریافت داده با سرویس‌های جعلی (پاسخ فوری)
    prices.fetchAll();

    await tester.pumpWidget(
      GoldOilPriceApp(pricesProvider: prices, themeProvider: ThemeProvider()),
    );

    // چند فریم برای پردازش پاسخ جعلی و رندر بنر و بخش‌ها
    await tester.pump();
    await tester.pump();

    // عنوان بنر پلنگ صورتی باید نمایش داده شود
    expect(find.text('قیمت لحظه‌ای طلا و نفت'), findsOneWidget);

    // نشان منبع داده فعال (پیش‌فرض: تالا)
    expect(find.text('منبع داده: تالا'), findsOneWidget);

    // سرصفحه بخش بازار جهانی
    expect(find.text('بازار جهانی'), findsOneWidget);

    // سرصفحه بخش نفت (از یاهو) و بازار ایران
    expect(find.text('نفت و انرژی'), findsOneWidget);
    expect(find.text('بازار ایران'), findsOneWidget);

    // کارت‌های جعلی باید رندر شده باشند
    expect(find.text('طلای ۱۸ عیار'), findsOneWidget);
    expect(find.text('نفت برنت'), findsOneWidget);
    expect(find.text('نفت WTI'), findsOneWidget);

    // مقدار نامعتبر (صفر/منفی) باید «—» نمایش داده شود
    expect(find.text('سکه امامی'), findsOneWidget);

    // پنل تازگی داده: شمارش معکوس رفرش خودکار باید دیده شود
    expect(find.textContaining('رفرش بعدی تا'), findsOneWidget);

    // سن داده (مُهر زمانی سرور برابر الان است)
    expect(find.textContaining('سن داده'), findsOneWidget);
  });

  test('پارس پاسخ واقعی TGJU: تبدیل ریال به تومان و گروه‌بندی درست',
      () async {
    // نمونه پاسخ با ساختار واقعی call.tgju.org/ajax.json
    final Map<String, dynamic> payload = <String, dynamic>{
      'current': <String, dynamic>{
        'geram18': <String, dynamic>{
          'p': '261,778,000',
          'd': '2406000',
          'dp': '0.93',
          'dt': 'high',
          't': '۲۷ مهر',
          'ts': '2026-10-19 00:00:00',
        },
        'sekee': <String, dynamic>{
          'p': '2,653,300,000',
          'd': '0',
          'dp': '0',
          'dt': '',
          't': '۲۷ مهر',
          'ts': '2026-10-19 00:00:00',
        },
        'ons': <String, dynamic>{
          'p': '4,142.08',
          'd': '3.66',
          'dp': '0.09',
          'dt': 'high',
          't': '۰۱:۴۳:۰۰',
          'ts': '2026-10-20 01:43:00',
        },
        'oil_brent': <String, dynamic>{
          'p': '109.118',
          'd': '0.166',
          'dp': '0.15',
          'dt': 'low',
          't': '۰۱:۴۳:۰۱',
          'ts': '2026-10-20 01:43:01',
        },
      },
    };

    final TgjuSource source = TgjuSource(
      client: MockClient((http.Request request) async => http.Response(
            jsonEncode(payload),
            200,
            // بدون این هدر، http بدنه را latin1 انکود می‌کند و متن فارسی می‌شکند
            headers: <String, String>{
              'content-type': 'application/json; charset=utf-8'
            },
          )),
    );

    final MarketSnapshot snapshot = await source.fetchSnapshot();

    // چهار ردیف معتبر باید برگردد
    expect(snapshot.items.length, 4);

    // طلای ۱۸ عیار: 261,778,000 ریال ÷ ۱۰ = ۲۶٬۱۷۷٬۸۰۰ تومان
    final PriceRow geram18 =
        snapshot.items.firstWhere((PriceRow r) => r.title == 'طلای ۱۸ عیار');
    expect(geram18.value, '۲۶٬۱۷۷٬۸۰۰٫۰۰');
    expect(geram18.unit, 'تومان برای هر گرم');
    expect(geram18.group, 'iran');
    expect(geram18.isUp, true);
    expect(geram18.changeText, '۰٫۹۳٪');

    // سکه امامی: بدون تغییر (dp=0) → بدون نشان تغییر
    final PriceRow sekee =
        snapshot.items.firstWhere((PriceRow r) => r.title == 'سکه امامی');
    expect(sekee.value, '۲۶۵٬۳۳۰٬۰۰۰٫۰۰');
    expect(sekee.changeText, isNull);
    expect(sekee.isUp, isNull);

    // انس جهانی: دلاری، بدون تبدیل
    final PriceRow ons =
        snapshot.items.firstWhere((PriceRow r) => r.title == 'اونس جهانی طلا');
    expect(ons.value, '۴٬۱۴۲٫۰۸');
    expect(ons.group, 'global');
    expect(ons.isUp, true);

    // برنت: نزولی (dt=low)
    final PriceRow brent =
        snapshot.items.firstWhere((PriceRow r) => r.title == 'نفت برنت');
    expect(brent.value, '۱۰۹٫۱۲');
    expect(brent.group, 'oil');
    expect(brent.isUp, false);
    expect(brent.changeText, '۰٫۱۵٪');

    // سن داده: بر اساس تازه‌ترین ts (2026-10-20 01:43:01 به وقت ایران)
    expect(snapshot.feedTimeMs, isNotNull);
    source.dispose();
  });

  test('ردیف‌های با مقدار صفر یا خراب در TGJU حذف می‌شوند', () async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'current': <String, dynamic>{
        'geram18': <String, dynamic>{
          'p': '0',
          'd': '0',
          'dp': '0',
          'dt': '',
        },
        'nim': <String, String>{
          'p': 'ناموجود',
          'd': '0',
          'dp': '0',
          'dt': '',
        },
        'rob': <String, dynamic>{
          'p': '744,500,000',
          'd': '-400000',
          'dp': '0.05',
          'dt': 'low',
          'ts': '2026-10-19 00:00:00',
        },
      },
    };

    final TgjuSource source = TgjuSource(
      client: MockClient((http.Request request) async => http.Response(
            jsonEncode(payload),
            200,
            headers: <String, String>{
              'content-type': 'application/json; charset=utf-8'
            },
          )),
    );

    final MarketSnapshot snapshot = await source.fetchSnapshot();

    // فقط ربع سکه معتبر است
    expect(snapshot.items.length, 1);
    expect(snapshot.items.first.title, 'ربع سکه');
    expect(snapshot.items.first.value, '۷۴٬۴۵۰٬۰۰۰٫۰۰');
    expect(snapshot.items.first.isUp, false);
    source.dispose();
  });
}
