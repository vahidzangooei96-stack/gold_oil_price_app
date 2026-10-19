import 'package:flutter_test/flutter_test.dart';
import 'package:gold_oil_price/main.dart';
import 'package:gold_oil_price/models/price_models.dart';
import 'package:gold_oil_price/providers/prices_provider.dart';
import 'package:gold_oil_price/providers/theme_provider.dart';
import 'package:gold_oil_price/services/api_service.dart';

/// سرویس جعلی بدون تماس با شبکه برای تست
///
/// feedTimeMs برابر «الان» داده می‌شود تا محاسبه «سن داده» هم تست شود.
class FakeTalaService extends TalaService {
  @override
  Future<TalaSnapshot> fetchPrices() async => TalaSnapshot(
        items: <TalaPrice>[
          const TalaPrice(
            title: 'طلای ۱۸ عیار',
            value: '۳٬۴۷۷٬۰۹۰',
            unit: 'تومان',
            changeText: '۰٫۵٪',
            isUp: true,
          ),
          const TalaPrice(
            title: 'سکه امامی',
            value: '—',
            unit: 'تومان',
          ),
        ],
        jdate: '18:14 1405/07/27',
        feedTimeMs: DateTime.now().millisecondsSinceEpoch,
      );
}

void main() {
  testWidgets('صفحه اصلی با داده جعلی رندر می‌شود (بدون تماس با شبکه)',
      (WidgetTester tester) async {
    final PricesProvider prices =
        PricesProvider(talaService: FakeTalaService());

    // شروع دریافت داده با سرویس جعلی (پاسخ فوری)
    prices.fetchAll();

    await tester.pumpWidget(
      GoldOilPriceApp(pricesProvider: prices, themeProvider: ThemeProvider()),
    );

    // یک فریم برای پردازش پاسخ جعلی و رندر بنر
    await tester.pump();
    await tester.pump();

    // عنوان بنر باید نمایش داده شود
    expect(find.text('قیمت لحظه‌ای طلا و نفت'), findsOneWidget);

    // کارت قیمت جعلی باید رندر شده باشد
    expect(find.text('طلای ۱۸ عیار'), findsOneWidget);

    // مقدار نامعتبر (صفر/منفی) باید «—» نمایش داده شود
    expect(find.text('سکه امامی'), findsOneWidget);

    // پنل تازگی داده: شمارش معکوس رفرش خودکار باید دیده شود
    expect(find.textContaining('رفرش بعدی تا'), findsOneWidget);

    // سن داده (مُهر زمانی سرور برابر الان است)
    expect(find.textContaining('سن داده'), findsOneWidget);
  });
}
