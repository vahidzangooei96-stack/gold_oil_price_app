import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/price_models.dart';
import '../providers/prices_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/price_card.dart';
import '../widgets/source_sheet.dart';
import '../widgets/status_views.dart';

/// صفحه اصلی «پلنگ صورتی»:
/// بنر پلنگ صورتی + بخش‌های بازار جهانی، نفت و بازار ایران
/// + دکمه تغییر منبع داده — تمام متن‌ها فارسی است.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PricesProvider prices = context.watch<PricesProvider>();
    final ThemeProvider themeProvider = context.watch<ThemeProvider>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // رنگ متن روی پس‌زمینه: گل‌بهی در تاریک، آلویی در روشن
    final Color onBg = isDark ? AppTheme.roseWhite : AppTheme.plumDark;

    return Scaffold(
      // پس‌زمینه و AppBar شفاف تا گرادیان صورتی دیده شود
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: <Widget>[
          // تغییر منبع داده (API ایرانی منتخب کاربر)
          IconButton(
            tooltip: 'تغییر منبع داده',
            onPressed: () => showSourceSheet(context, prices),
            icon: Icon(Icons.swap_horiz, color: onBg),
          ),
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
            color: AppTheme.pink,
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
    final List<PriceRow> globalItems = prices.items
        .where((PriceRow r) => r.group == 'global')
        .toList();
    final List<PriceRow> oilItems =
        prices.items.where((PriceRow r) => r.group == 'oil').toList();
    final List<PriceRow> iranItems =
        prices.items.where((PriceRow r) => r.group == 'iran').toList();

    // ۴) نمایش داده‌ها — در نمایشگر عریض دو ستونه می‌شود
    final bool isWide = constraints.maxWidth >= 700;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: <Widget>[
            _buildPantherBanner(context),

            const SizedBox(height: 12),

            // نشان منبع داده فعال — با لمس، شیت تغییر منبع باز می‌شود
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => showSourceSheet(context, prices),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.pink.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: AppTheme.pink.withOpacity(0.45)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.swap_horiz,
                          size: 16, color: isDark ? AppTheme.pinkLight : AppTheme.pink),
                      const SizedBox(width: 6),
                      Text(
                        'منبع داده: ${prices.sourceName}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: onBg,
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down,
                          size: 18, color: onBg.withOpacity(0.6)),
                    ],
                  ),
                ),
              ),
            ),

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

            // تحلیل لحظه‌ای بازار
            if (_insight(prices) != null)
              _buildInsight(context, _insight(prices)!, onBg),

            const SizedBox(height: 16),

            // پنل تازگی داده و شمارش معکوس رفرش
            _buildFreshnessPanel(prices, onBg),
            const SizedBox(height: 8),
            Text(
              'بروزرسانی خودکار هر ۳۰ ثانیه — منبع: ${prices.sourceName} + نفت جهانی از یاهو',
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
  List<Widget> _cards(List<PriceRow> rows) {
    return rows.map((PriceRow r) => PriceCard(price: r)).toList();
  }

  /// بنر پلنگ صورتی: کاراکتر پلنگ + سکه طلا و بشکه نفت + عنوان فارسی
  Widget _buildPantherBanner(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          Image.asset(
            'assets/images/pink_panther.jpg',
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          // لایه تیره پایین بنر برای خوانایی متن صورتی
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    const Color(0xFF1A0A13).withOpacity(0.85),
                  ],
                  stops: const <double>[0.42, 1.0],
                ),
              ),
            ),
          ),
          // قاب خط صورتی دور بنر
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.pink.withOpacity(0.6)),
              ),
            ),
          ),
          const Positioned(
            right: 18,
            bottom: 14,
            left: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  'قیمت لحظه‌ای طلا و نفت',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.pinkLight,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'پلنگ صورتی · سریع · شیک · همیشه بروز',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.roseWhite,
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
        // سرصفحه: آیکون صورتی + عنوان + خط صورتی
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: AppTheme.pinkGradient,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: const Color(0xFF2B0A1B),
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
                      AppTheme.pink.withOpacity(0.6),
                      AppTheme.pink.withOpacity(0.0),
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
    PriceRow? gold;
    PriceRow? oil;
    for (final PriceRow r in prices.items) {
      if (gold == null && r.title.contains('اونس')) gold = r;
      if (oil == null && r.title.contains('برنت')) oil = r;
    }

    if (gold == null && oil == null) return null;

    final bool? goldUp = gold?.isUp;
    final bool? oilUp = oil?.isUp;

    if (goldUp == true && oilUp == true) {
      return 'طلا و نفت هم‌زمان صعودی‌اند — پلنگ گوش‌هایش را تیز کرده؛ بازار داغ است!';
    }
    if (goldUp == true && oilUp == false) {
      return 'طلا صعودی و نفت نزولی — پناهگاه امن، قدرت را حفظ کرده است.';
    }
    if (goldUp == false && oilUp == true) {
      return 'نفت پیشتاز شده و طلا عقب‌نشینی می‌کند — پول به سوی انرژی می‌رود.';
    }
    if (goldUp == false && oilUp == false) {
      return 'طلا و نفت هر دو نزولی‌اند — بازار نفس تازه می‌کند؛ صبر، هنر پلنگ است.';
    }
    return 'بازار امروز آرام است — قیمت‌ها در محدوده باریکی نوسان می‌کنند.';
  }

  /// جعبه تحلیل بازار با قاب صورتی
  Widget _buildInsight(BuildContext context, String text, Color onBg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.pink.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.pink.withOpacity(0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.auto_awesome, size: 18, color: AppTheme.pink),
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
        color: AppTheme.pink.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.pink.withOpacity(0.3)),
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
                fresh ? AppTheme.pink : Colors.orangeAccent,
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
