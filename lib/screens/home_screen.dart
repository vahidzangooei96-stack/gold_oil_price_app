import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/prices_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/formatters.dart';
import '../widgets/price_card.dart';
import '../widgets/status_views.dart';

/// صفحه اصلی: دو کارت بزرگ قیمت طلا و نفت برنت + رفرش دستی و خودکار
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PricesProvider prices = context.watch<PricesProvider>();
    final ThemeProvider themeProvider = context.watch<ThemeProvider>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('قیمت لحظه‌ای طلا و نفت'),
        actions: <Widget>[
          // سوییچ پوسته: سیستم / تاریک / روشن
          IconButton(
            tooltip: themeProvider.tooltip,
            onPressed: themeProvider.toggle,
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
          // رفرش دستی
          IconButton(
            tooltip: 'بروزرسانی قیمت‌ها',
            onPressed:
                prices.isLoading ? null : () => prices.fetchAll(),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => prices.fetchAll(showLoading: false),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return _buildBody(context, prices, constraints);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PricesProvider prices,
    BoxConstraints constraints,
  ) {
    final bool hasNoData = prices.gold == null && prices.brent == null;

    // ۱) بارگذاری اولیه
    if (prices.isLoading && hasNoData) return const LoadingView();

    // ۲) خطای کامل (هیچ داده‌ای از قبل موجود نیست)
    if (hasNoData && prices.errorMessage != null) {
      return ErrorView(
        message: prices.errorMessage!,
        onRetry: () => prices.fetchAll(),
      );
    }

    // ۳) نمایش داده‌ها
    final bool isWide = constraints.maxWidth >= 720;

    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Widget goldCard = PriceCard(
      title: 'انس طلا',
      symbol: 'XAU / USD',
      icon: Icons.currency_exchange,
      unit: 'دلار آمریکا برای هر اونس',
      data: prices.gold,
      containerColor: scheme.primaryContainer,
      onContainerColor: scheme.onPrimaryContainer,
    );

    final Widget brentCard = PriceCard(
      title: 'نفت برنت',
      symbol: 'BRENT CRUDE / USD',
      icon: Icons.oil_barrel_outlined,
      unit: 'دلار آمریکا برای هر بشکه',
      data: prices.brent,
      containerColor: scheme.secondaryContainer,
      onContainerColor: scheme.onSecondaryContainer,
    );

    // در نمایشگرهای عریض (تبلت/افقی) کارت‌ها کنار هم قرار می‌گیرند
    final List<Widget> cards = isWide
        ? <Widget>[
            Expanded(child: goldCard),
            const SizedBox(width: 16),
            Expanded(child: brentCard),
          ]
        : <Widget>[
            goldCard,
            const SizedBox(height: 16),
            brentCard,
          ];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              // اگر داده‌های قبلی موجودند ولی آپدیت جدید شکست خورده،
              // هشدار ملایم بالای صفحه نشان داده می‌شود
              if (prices.errorMessage != null)
                _partialErrorBanner(context, prices.errorMessage!),
              Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                mainAxisSize: MainAxisSize.min,
                children: cards,
              ),
              const SizedBox(height: 28),
              _buildLastUpdated(prices),
              const SizedBox(height: 6),
              Text(
                'بروزرسانی خودکار هر ۳۰ ثانیه انجام می‌شود',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withOpacity(0.5),
                    ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// بنر هشدار برای حالتی که داده‌های قبلی نمایش داده می‌شوند
  /// ولی آپدیت تازه ناموفق بوده است
  Widget _partialErrorBanner(BuildContext context, String message) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.wifi_off, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$message — قیمت‌ها ممکن است قدیمی باشند.',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ردیف زمان آخرین بروزرسانی موفق
  Widget _buildLastUpdated(PricesProvider prices) {
    final DateTime? time = prices.lastUpdated;
    if (time == null) return const SizedBox.shrink();
    return Text(
      'آخرین بروزرسانی: ${Formatters.clock(time)}',
      style: const TextStyle(fontSize: 14),
    );
  }
}
