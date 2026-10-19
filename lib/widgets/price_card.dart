import 'package:flutter/material.dart';

import '../models/price_models.dart';
import '../theme/app_theme.dart';

/// کارت فانتزی نمایش قیمت — حباب‌های گرد با حاشیه صورتی/آبی متناوب
class PriceCard extends StatelessWidget {
  const PriceCard({
    super.key,
    required this.price,
    this.accentPink = true,
  });

  final TalaPrice price;

  /// رنگ حاشیه کارت: صورتی یا آبی (به‌صورت متناوب برای تنوع بصری)
  final bool accentPink;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color accent =
        accentPink ? AppTheme.seedPink : AppTheme.skyBlue;

    // رنگ متن روی کارت
    final Color valueColor = isDark ? Colors.white : const Color(0xFF3A1C52);
    final Color titleColor =
        isDark ? Colors.white.withOpacity(0.95) : const Color(0xFF5A2E77);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.80),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withOpacity(0.55), width: 1.3),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withOpacity(isDark ? 0.15 : 0.20),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ── ردیف بالا: ستاره فانتزی + عنوان + نشان تغییر ──
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: <Color>[AppTheme.seedPink, AppTheme.skyBlue],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  accentPink ? Icons.auto_awesome : Icons.star_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  price.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
              ),
              _buildChangeChip(theme),
            ],
          ),
          const SizedBox(height: 10),

          // ── قیمت با فونت بزرگ ──
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              price.value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: valueColor,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // ── واحد قیمت زیر عدد ──
          Text(
            price.unit,
            style: theme.textTheme.bodySmall?.copyWith(
              color: titleColor.withOpacity(0.65),
            ),
          ),
        ],
      ),
    );
  }

  /// نشان درصد تغییر (سبز = افزایش، قرمز = کاهش)
  Widget _buildChangeChip(ThemeData theme) {
    final String? change = price.changeText;
    if (change == null) return const SizedBox.shrink();

    final bool? up = price.isUp;
    if (up == null) return const SizedBox.shrink();

    final Color color = up ? const Color(0xFF27AE60) : const Color(0xFFE74C3C);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            up ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            color: color,
            size: 18,
          ),
          Text(
            change,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
