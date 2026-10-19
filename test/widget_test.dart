import 'package:flutter_test/flutter_test.dart';
import 'package:gold_oil_price/main.dart';
import 'package:gold_oil_price/models/price_models.dart';
import 'package:gold_oil_price/providers/prices_provider.dart';
import 'package:gold_oil_price/providers/theme_provider.dart';
import 'package:gold_oil_price/services/api_service.dart';
import 'package:gold_oil_price/services/yahoo_service.dart';

/// سرویس جعلی tala.ir بدون تماس با شبکه برای تست
///
/// feedTimeMs برابر «الان» داده می‌شود تا محاسبه «سن داده» هم تست شود.
class FakeTalaService extends TalaService {
  @override
  Future<TalaSnapshot> fetchPrices() async => TalaSnapshot(
        items: <TalaPrice>[
          const TalaPrice(
            title: 'اونس جهانی طلا',
            value: '۲٬۶۵۰٫۳۵',
            unit: 'دلار برای هر اونس',
            changeText: '۰٫۵٪',
            isUp: true,
            group: 'global',
          ),
          const TalaPrice(
            title: 'طلای ۱۸ عیار',
            value: '۳٬۴۷۷٬۰۹۰',
            unit: 'تومان برای هر گرم',
            changeText: '۰٫۵٪',
            isUp: true,
            group: 'iran',
          ),
          const TalaPrice(
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
  Future<List<TalaPrice>> fetchOilQuotes() async => const <TalaPrice>[
        TalaPrice(
          title: 'نفت برنت',
          value: '۱۰۹٫۳۸',
          unit: 'دلار برای هر بشکه',
          changeText: '۱٫۵۷٪',
          isUp: true,
          group: 'oil',
        ),
        TalaPrice(
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
      talaService: FakeTalaService(),
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

    // عنوان بنر لوکس باید نمایش داده شود
    expect(find.text('امپراتوری طلا و نفت'), findsOneWidget);

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
}
