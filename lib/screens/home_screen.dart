import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/prices_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/price_card.dart';
import '../widgets/status_views.dart';

/// صفحه اصلی فانتزی: بنر اگری و الاغ + لیست قیمت‌های صفحه اصلی tala.ir
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PricesProvider prices = context.watch<PricesProvider>();
    final ThemeProvider themeProvider = context.watch<ThemeProvider>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // رنگ متن‌های روی پس‌زمینه گرادیان — در حالت روشن بنفش تیره
    final Color onBg = isDark ? Colors.white : const Color(0xFF6B2E8F);

    return Scaffold(
      // پس‌زمینه و AppBar شفاف تا گرادیان فانتزی دیده شود
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(''),
        actions: <Widget>[
          // سوییچ پوسته: سیستم / تاریک / روشن
          IconButton(
            tooltip: themeProvider.tooltip,
            onPressed: themeProvider.toggle,
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: onBg,
            ),
          ),
          // رفرش دستی
          IconButton(
            tooltip: 'بروزرسانی قیمت‌ها',
            onPressed: prices.isLoading ? null : () => prices.fetchAll(),
            icon: Icon(Icons.refresh, color: onBg),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: AppTheme.darkGradient,
          ),
        ),
        child: SafeArea(
          top: true,
          child: RefreshIndicator(
            color: AppTheme.seedPink,
            onRefresh: () => prices.fetchAll(showLoading: false),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return _buildBody(context, prices, constraints, onBg);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PricesProvider prices,
    BoxConstraints constraints,
    Color onBg,
  ) {
    // ۱) بارگذاری اولیه
    if (prices.isLoading && prices.items.isEmpty) return const LoadingView();

    // ۲) خطای کامل (هیچ داده‌ای موجود نیست)
    if (prices.items.isEmpty && prices.errorMessage != null) {
      return ErrorView(
        message: prices.errorMessage!,
        onRetry: () => prices.fetchAll(),
      );
    }

    // ۳) نمایش داده‌ها — در نمایشگر عریض دو ستونه می‌شود
    final bool isWide = constraints.maxWidth >= 700;

    final List<Widget> cards = <Widget>[];
    for (int i = 0; i < prices.items.length; i++) {
      cards.add(PriceCard(
        price: prices.items[i],
        accentPink: i.isEven,
      ));
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: <Widget>[
            _buildFantasyBanner(context),

            // هشدار ملایم وقتی داده قبلی نمایش داده می‌شود ولی آپدیت شکست خورده
            if (prices.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _partialErrorBanner(context, prices.errorMessage!, onBg),
            ],

            const SizedBox(height: 8),
            if (isWide)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.8,
                children: cards,
              )
            else
              Column(
                children: <Widget>[
                  for (int i = 0; i < cards.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: 12),
                    cards[i],
                  ],
                ],
              ),

            const SizedBox(height: 24),
            _buildFreshnessPanel(prices, onBg),
            const SizedBox(height: 8),
            Text(
              'بروزرسانی خودکار هر ۳۰ ثانیه — منبع: tala.ir',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: onBg.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// بنر فانتزی: تصویر اگری و الاغ + عنوان اپ
  Widget _buildFantasyBanner(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          Image.asset(
            'assets/images/ogre_donkey.jpg',
            height: 190,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          // گرادیان پایین بنر برای خوانایی متن
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Colors.black.withOpacity(0.55),
                  ],
                  stops: const <double>[0.45, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 12,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'قیمت لحظه‌ای طلا و نفت',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'در دنیای فانتزی اگری و الاغش',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// بنر هشدار برای حالتی که داده‌های قبلی نمایش داده می‌شوند
  /// ولی آپدیت تازه ناموفق بوده است
  Widget _partialErrorBanner(BuildContext context, String message, Color onBg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withOpacity(0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepOrangeAccent.withOpacity(0.45)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.wifi_off, size: 18, color: onBg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$message — قیمت‌ها ممکن است قدیمی باشند.',
              style: TextStyle(fontSize: 13, color: onBg),
            ),
          ),
        ],
      ),
    );
  }

  /// پنل تازگی داده: نشانه می‌دهد که اپ واقعاً هر ۳۰ ثانیه
  /// در حال گرفتن تازه‌ترین داده‌ها است:
  ///  ۱) ساعت آخرین دریافت موفق (ساعت دستگاه)
  ///  ۲) سن داده نسبت به مُهر زمانی خود سرور (مثل نمایش سایت)
  ///  ۳) شمارش معکوس و نوار پیشرفت تا رفرش بعدی
  Widget _buildFreshnessPanel(PricesProvider prices, Color onBg) {
    final bool fresh = !prices.isStale && prices.lastFetchAt != null;
    final Color dotColor = fresh ? Colors.lightGreenAccent : Colors.orangeAccent;

    final String? ageText = _dataAgeText(prices);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: (isPanelDark(onBg) ? Colors.white : Colors.deepPurple).withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: onBg.withOpacity(0.15)),
      ),
      child: Column(
        children: <Widget>[
          // ردیف ۱: آخرین دریافت موفق + چراغ وضعیت تازگی
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.verified, size: 16, color: dotColor),
              const SizedBox(width: 6),
              Text(
                prices.lastFetchAt == null
                    ? 'در انتظار اولین دریافت...'
                    : 'آخرین دریافت: ${Formatters.clock(prices.lastFetchAt!)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: onBg.withOpacity(0.9),
                ),
              ),
            ],
          ),
          // ردیف ۲: سن داده از دید سرور
          if (ageText != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'سن داده: $ageText',
              style: TextStyle(
                fontSize: 12,
                color: onBg.withOpacity(0.7),
              ),
            ),
          ],
          const SizedBox(height: 10),
          // نوار پیشرفت + شمارش معکوس تا رفرش بعدی
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: 1 - prices.secondsToNextRefresh / PricesProvider.autoRefreshSeconds,
              minHeight: 5,
              backgroundColor: onBg.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                fresh ? AppTheme.seedPink : Colors.orangeAccent,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'رفرش بعدی تا ${Formatters.toPersianDigits('${prices.secondsToNextRefresh}')} ثانیه',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: onBg.withOpacity(0.75),
            ),
          ),
        ],
      ),
    );
  }

  /// متن «سن داده» مثل سایت: چند ثانیه/دقیقه پیش
  String? _dataAgeText(PricesProvider prices) {
    final int? age = prices.dataAgeSeconds;
    if (age == null) return null;
    if (age < 60) return '${Formatters.toPersianDigits('$age')} ثانیه پیش';
    final int minutes = age ~/ 60;
    return '${Formatters.toPersianDigits('$minutes')} دقیقه پیش';
  }

  /// تشخیص متن پنل: اگر رنگ متن روشن باشد یعنی پس‌زمینه تاریک است
  bool isPanelDark(Color onBg) => onBg.computeLuminance() > 0.5;
}
