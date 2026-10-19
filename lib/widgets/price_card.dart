import 'package:flutter/material.dart';

import '../models/price_models.dart';
import '../theme/app_theme.dart';

/// کارت نمایش قیمت — قاب صورتی پلنگ روی بادمجانی تیره
class PriceCard extends StatelessWidget {
  const PriceCard({super.key, required this.price});

  final PriceRow price;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    // رنگ‌های متن روی کارت
    final Color valueColor = isDark ? AppTheme.pinkLight : AppTheme.plumDark;
    final Color titleColor =
        isDark ? AppTheme.roseWhite.withOpacity(0.92) : AppTheme.plumDark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: <Color>[Color(0xFF2A1120), Color(0xFF1D0B16)],
              )
            : const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: <Color>[AppTheme.cardLight, Color(0xFFFBE4EF)],
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.pink.withOpacity(0.55), width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.45 : 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ── ردیف بالا: نشان پنجه صورتی + عنوان + نشان تغییر ──
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: AppTheme.pinkGradient,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.workspace_premium_outlined,
                  color: isDark ? const Color(0xFF2B0A1B) : Colors.white,
                  size: 15,
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
              _buildChangeChip(),
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
              color: titleColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// نشان درصد تغییر (سبز = افزایش، قرمز = کاهش)
  Widget _buildChangeChip() {
    final String? change = price.changeText;
    if (change == null) return const SizedBox.shrink();

    final bool? up = price.isUp;
    if (up == null) return const SizedBox.shrink();

    final Color color = up ? AppTheme.gain : AppTheme.loss;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
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
