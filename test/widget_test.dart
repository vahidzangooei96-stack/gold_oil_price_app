import 'package:flutter_test/flutter_test.dart';
import 'package:gold_oil_price/main.dart';
import 'package:gold_oil_price/providers/prices_provider.dart';
import 'package:gold_oil_price/providers/theme_provider.dart';
import 'package:gold_oil_price/services/api_service.dart';

/// سرویس جعلی بدون تماس با شبکه برای تست
class FakeApiService extends ApiService {
  @override
  Future<double> fetchGoldPrice() async => 2650.35;

  @override
  Future<double> fetchBrentPrice() async => 73.42;
}

void main() {
  testWidgets('صفحه اصلی بدون تماس با شبکه رندر می‌شود',
      (WidgetTester tester) async {
    final PricesProvider prices = PricesProvider(apiService: FakeApiService());

    await tester.pumpWidget(
      GoldOilPriceApp(pricesProvider: prices, themeProvider: ThemeProvider()),
    );
    await tester.pump();

    // عنوان صفحه باید نمایش داده شود
    expect(find.text('قیمت لحظه‌ای طلا و نفت'), findsOneWidget);

    // چون fetchAll فراخوانی نشده، باید حالت بارگذاری دیده شود
    expect(find.text('در حال دریافت قیمت‌ها…'), findsOneWidget);
  });
}
