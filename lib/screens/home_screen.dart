import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/price_models.dart';
import '../providers/prices_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/price_card.dart';
import '../widgets/status_views.dart';

/// صفحه اصلی لوکس «امپراتوری طلا و نفت»:
/// بنر نشان شیر طلایی + بخش‌های بازار جهانی، نفت و بازار ایران
/// تمام متن‌ها فارسی است.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PricesProvider prices = context.watch<PricesProvider>();
    final ThemeProvider themeProvider = context.watch<ThemeProvider>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // رنگ متن روی پس‌زمینه: عاج در تاریک، برنز در روشن
    final Color onBg = isDark ? AppTheme.ivory : AppTheme.bronzeDark;

    return Scaffold(
      // پس‌زمینه و AppBar شفاف تا گرادیان لوکس دیده شود
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: isDark ? AppTheme.darkGradient : AppTheme.lightGradient,
          ),
        ),
        child: SafeArea(
          top: true,
          child: RefreshIndicator(
            color: AppTheme.gold,
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

    // ۳) گروه‌بندی ردیف‌ها برای بخش‌های صفحه
    final List<TalaPrice> globalItems = prices.items
        .where((TalaPrice r) => r.group == 'global')
        .toList();
    final List<TalaPrice> oilItems =
        prices.items.where((TalaPrice r) => r.group == 'oil').toList();
    final List<TalaPrice> iranItems =
        prices.items.where((TalaPrice r) => r.group == 'iran').toList();

    // ۴) نمایش داده‌ها — در نمایشگر عریض دو ستونه می‌شود
    final bool isWide = constraints.maxWidth >= 700;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: <Widget>[
            _buildLuxuryBanner(context),

            const SizedBox(height: 16),

            // بخش بازار جهانی: اونس طلا و نقره
            if (globalItems.isNotEmpty)
              _buildSection(
                context,
                title: 'بازار جهانی',
                subtitle: 'پناهگاه امن. قدرت بی‌پایان.',
                icon: Icons.workspace_premium_outlined,
                cards: _cards(globalItems),
                isWide: isWide,
                onBg: onBg,
              ),

            // بخش نفت و انرژی: برنت و WTI
            if (oilItems.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              _buildSection(
                context,
                title: 'نفت و انرژی',
                subtitle: 'طلای سیاه. قدرت واقعی.',
                icon: Icons.local_fire_department_outlined,
                cards: _cards(oilItems),
                isWide: isWide,
                onBg: onBg,
              ),
            ],

            // بخش بازار ایران: مثقال، عیارها و سکه‌ها
            if (iranItems.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              _buildSection(
                context,
                title: 'بازار ایران',
                subtitle: 'طلای داخلی. سرمایه ماندگار.',
                icon: Icons.account_balance_outlined,
                cards: _cards(iranItems),
                isWide: isWide,
                onBg: onBg,
              ),
            ],

            const SizedBox(height: 16),

            // هشدارها: خطای منبع اصلی یا خطای بخش نفت
            if (prices.errorMessage != null)
              _warnBanner(
                context,
                '${prices.errorMessage!} — قیمت‌ها ممکن است قدیمی باشند.',
                onBg,
              )
            else if (prices.oilError != null)
              _warnBanner(context, prices.oilError!, onBg),

            const SizedBox(height: 12),

            // تحلیل لحظه‌ای بازار (مثل خط «نگاه بازار» در طرح‌های لوکس)
            if (_insight(prices) != null)
              _buildInsight(context, _insight(prices)!, onBg),

            const SizedBox(height: 16),

            // پنل تازگی داده و شمارش معکوس رفرش
            _buildFreshnessPanel(prices, onBg),
            const SizedBox(height: 8),
            Text(
              'بروزرسانی خودکار هر ۳۰ ثانیه — منابع: tala.ir و یاهو فایننس',
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

  /// ساخت کارت‌های قیمت از ردیف‌های داده
  List<Widget> _cards(List<TalaPrice> rows) {
    return rows.map((TalaPrice r) => PriceCard(price: r)).toList();
  }

  /// بنر لوکس: نشان شیر طلایی + عنوان و شعار کاملاً فارسی
  Widget _buildLuxuryBanner(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          Image.asset(
            'assets/images/lion_crest.jpg',
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          // لایه تیره پایین بنر برای خوانایی متن طلایی
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Colors.black.withOpacity(0.72),
                  ],
                  stops: const <double>[0.40, 1.0],
                ),
              ),
            ),
          ),
          // قاب خط طلایی دور بنر
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.gold.withOpacity(0.55)),
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 14,
            left: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'امپراتوری طلا و نفت',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.goldLight,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'مالی · قدرت · احترام',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.ivory.withOpacity(0.85),
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// سرصفحه یک بخش بازار + کارت‌هایش
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> cards,
    required bool isWide,
    required Color onBg,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // سرصفحه: آیکون طلایی + عنوان + خط طلایی
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: AppTheme.goldGradient,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: const Color(0xFF14110B),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: onBg,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: onBg.withOpacity(0.55),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppTheme.gold.withOpacity(0.6),
                      AppTheme.gold.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
      ],
    );
  }

  /// بنر هشدار ملایم (خطای منبع‌ها وقتی داده‌ای برای نمایش هست)
  Widget _warnBanner(BuildContext context, String message, Color onBg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: Colors.deepOrangeAccent.withOpacity(0.45)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.wifi_off, size: 18, color: onBg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: onBg),
            ),
          ),
        ],
      ),
    );
  }

  /// تحلیل خودکار بازار بر اساس جهت تغییرها — کاملاً فارسی
  String? _insight(PricesProvider prices) {
    TalaPrice? gold;
    TalaPrice? oil;
    for (final TalaPrice r in prices.items) {
      if (gold == null && r.title.contains('اونس')) gold = r;
      if (oil == null && r.title.contains('برنت')) oil = r;
    }

    if (gold == null && oil == null) return null;

    final bool? goldUp = gold?.isUp;
    final bool? oilUp = oil?.isUp;

    if (goldUp == true && oilUp == true) {
      return 'طلا و نفت هم‌زمان صعودی‌اند — بازار در انتظار یک رویداد بزرگ است.';
    }
    if (goldUp == true && oilUp == false) {
      return 'طلا صعودی و نفت نزولی — پناهگاه امن، قدرت را حفظ کرده است.';
    }
    if (goldUp == false && oilUp == true) {
      return 'نفت پیشتاز شده و طلا عقب‌نشینی می‌کند — پول به سوی انرژی می‌رود.';
    }
    if (goldUp == false && oilUp == false) {
      return 'طلا و نفت هر دو نزولی‌اند — بازار نفس تازه می‌کند؛ صبر، هنر بزرگان است.';
    }
    return 'بازار امروز آرام است — قیمت‌ها در محدوده باریکی نوسان می‌کنند.';
  }

  /// جعبه تحلیل بازار با قاب طلایی
  Widget _buildInsight(BuildContext context, String text, Color onBg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.gold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gold.withOpacity(0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.auto_awesome, size: 18, color: AppTheme.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: onBg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// پنل تازگی داده: اثبات می‌کند اپ واقعاً هر ۳۰ ثانیه رفرش می‌کند:
  ///  ۱) ساعت آخرین دریافت موفق (ساعت دستگاه)
  ///  ۲) سن داده نسبت به مُهر زمانی خود سرور
  ///  ۳) شمارش معکوس و نوار پیشرفت تا رفرش بعدی
  Widget _buildFreshnessPanel(PricesProvider prices, Color onBg) {
    final bool fresh = !prices.isStale && prices.lastFetchAt != null;
    final Color dotColor = fresh ? AppTheme.gain : Colors.orangeAccent;

    final String? ageText = _dataAgeText(prices);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.gold.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.gold.withOpacity(0.3)),
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
                    ? 'در انتظار اولین دریافت…'
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
              value: 1 -
                  prices.secondsToNextRefresh /
                      PricesProvider.autoRefreshSeconds,
              minHeight: 5,
              backgroundColor: onBg.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                fresh ? AppTheme.gold : Colors.orangeAccent,
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
}
