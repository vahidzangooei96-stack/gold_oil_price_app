import 'package:flutter/material.dart';

import '../models/price_models.dart';
import '../utils/formatters.dart';

/// کارت بزرگ نمایش قیمت برای هر نماد (انس طلا یا نفت برنت)
class PriceCard extends StatelessWidget {
  const PriceCard({
    super.key,
    required this.title,
    required this.symbol,
    required this.icon,
    required this.unit,
    required this.containerColor,
    required this.onContainerColor,
    this.data,
  });

  /// عنوان فارسی نماد، مانند «انس طلا»
  final String title;

  /// نماد لاتین، مانند XAU/USD
  final String symbol;

  /// آیکون نماد
  final IconData icon;

  /// واحد قیمت که زیر عدد نمایش داده می‌شود
  final String unit;

  /// رنگ پس‌زمینه کارت (از ColorScheme تم)
  final Color containerColor;

  /// رنگ محتوای روی کارت
  final Color onContainerColor;

  /// داده قیمت (null یعنی هنوز دریافت نشده)
  final PriceData? data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            containerColor.withOpacity(isDark ? 0.30 : 0.85),
            containerColor.withOpacity(isDark ? 0.10 : 0.45),
          ],
        ),
        border: Border.all(
          color: onContainerColor.withOpacity(isDark ? 0.15 : 0.10),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ── سربرگ کارت: آیکون + نام نماد + نشان تغییر ──
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: onContainerColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: onContainerColor, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: onContainerColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      symbol,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onContainerColor.withOpacity(0.7),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              _buildChangeBadge(),
            ],
          ),
          const SizedBox(height: 28),

          // ── قیمت اصلی با فونت بزرگ ──
          SizedBox(
            height: 72,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: data == null
                  ? _placeholder(theme)
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        Formatters.price(data!.price),
                        key: ValueKey<double>(data!.price),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: onContainerColor,
                          height: 1.1,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),

          // ── واحد قیمت زیر عدد ──
          Text(
            unit,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onContainerColor.withOpacity(0.75),
            ),
          ),
        ],
      ),
    );
  }

  /// نشان کوچک تغییر قیمت نسبت به دریافت قبلی (سبز/قرمز)
  Widget _buildChangeBadge() {
    final double? change = data?.change;
    if (change == null || change == 0) return const SizedBox.shrink();

    final bool isUp = change > 0;
    final Color color =
        isUp ? const Color(0xFF2E9E5B) : const Color(0xFFD64545);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            color: color,
            size: 22,
          ),
          Text(
            Formatters.price(change.abs()),
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// اسکلت جایگزین تا رسیدن داده‌ها
  Widget _placeholder(ThemeData theme) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 180,
            height: 34,
            decoration: BoxDecoration(
              color: onContainerColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 110,
            height: 14,
            decoration: BoxDecoration(
              color: onContainerColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}
