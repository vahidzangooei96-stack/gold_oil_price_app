import 'package:flutter_test/flutter_test.dart';
import 'package:gold_oil_price/main.dart';
import 'package:gold_oil_price/models/price_models.dart';
import 'package:gold_oil_price/providers/prices_provider.dart';
import 'package:gold_oil_price/providers/theme_provider.dart';
import 'package:gold_oil_price/services/api_service.dart';

/// سرویس جعلی بدون تماس با شبکه برای تست
class FakeTalaService extends TalaService {
  @override
  Future<TalaSnapshot> fetchPrices() async => const TalaSnapshot(
        items: <TalaPrice>[
          TalaPrice(
            title: 'طلای ۱۸ عیار',
            value: '۳٬۴۷۷٬۰۹۰',
            unit: 'تومان',
            changeText: '۰٫۵٪',
            isUp: true,
          ),
        ],
        jdate: '18:14 1405/07/27',
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
  });
}
