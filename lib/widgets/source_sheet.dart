import 'package:flutter/material.dart';

import '../providers/prices_provider.dart';
import '../services/source_registry.dart';
import '../theme/app_theme.dart';

/// شیت انتخاب منبع داده قیمت‌ها
///
/// کاربر می‌تواند بین APIهای ایرانی (تالا، TGJU، API رسمی تالا)
/// جابه‌جا شود؛ انتخاب در حافظه دستگاه ذخیره می‌شود.
/// منبع کلیددار (API رسمی تالا) فیلد ورود کلید API نشان می‌دهد.
Future<void> showSourceSheet(BuildContext context, PricesProvider prices) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      final bool dark = Theme.of(sheetContext).brightness == Brightness.dark;
      return _SourceSheet(prices: prices, dark: dark);
    },
  );
}

class _SourceSheet extends StatefulWidget {
  const _SourceSheet({required this.prices, required this.dark});

  final PricesProvider prices;
  final bool dark;

  @override
  State<_SourceSheet> createState() => _SourceSheetState();
}

class _SourceSheetState extends State<_SourceSheet> {
  /// شناسه گزینه در حال انتخاب (برای نمایش فیلد کلید)
  String? _expandedId;

  final TextEditingController _keyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _keyController.text = widget.prices.apiKey;
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Color get _surface =>
      widget.dark ? AppTheme.cardDark : AppTheme.cardLight;

  Color get _onSurface =>
      widget.dark ? AppTheme.roseWhite : AppTheme.plumDark;

  @override
  Widget build(BuildContext context) {
    final PricesProvider prices = widget.prices;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
          border: Border.all(color: AppTheme.pink.withOpacity(0.4)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // دستگیره شیت
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _onSurface.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // عنوان شیت
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.swap_horiz, color: AppTheme.pink),
                  const SizedBox(width: 8),
                  Text(
                    'منبع داده قیمت‌ها',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'API ایرانی موردنظرتان را انتخاب کنید؛ انتخاب شما ذخیره می‌شود.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: _onSurface.withOpacity(0.65),
                ),
              ),
              const SizedBox(height: 14),

              // گزینه‌های منبع
              for (final option in prices.sourceOptions) ...<Widget>[
                _buildOptionTile(option),
                if (_expandedId == option.id && option.requiresKey)
                  _buildKeyField(),
              ],

              const SizedBox(height: 8),
              Text(
                'نفت جهانی (برنت و WTI) همیشه از یاهو فایننس گرفته می‌شود.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: _onSurface.withOpacity(0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// کاشی یک گزینه منبع داده
  Widget _buildOptionTile(SourceOption option) {
    final PricesProvider prices = widget.prices;
    final bool selected = prices.sourceId == option.id;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.pink.withOpacity(0.10)
            : _onSurface.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? AppTheme.pink.withOpacity(0.6)
              : _onSurface.withOpacity(0.10),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        onTap: () => _onSelect(option),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: AppTheme.pinkGradient)
                : null,
            color: selected ? null : _onSurface.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            option.requiresKey ? Icons.vpn_key_outlined : Icons.public,
            size: 18,
            color: selected ? Colors.white : _onSurface.withOpacity(0.7),
          ),
        ),
        title: Text(
          option.name,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: selected ? AppTheme.pink : _onSurface,
          ),
        ),
        subtitle: Text(
          option.description,
          style: TextStyle(
            fontSize: 11.5,
            color: _onSurface.withOpacity(0.65),
            height: 1.5,
          ),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle, color: AppTheme.pink)
            : Icon(
                Icons.radio_button_off,
                color: _onSurface.withOpacity(0.35),
              ),
      ),
    );
  }

  /// فیلد ورود کلید API برای منبع کلیددار
  Widget _buildKeyField() {
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.pink.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.pink.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'کلید API خود را از api.tala.ir بگیرید و اینجا وارد کنید:',
            style: TextStyle(fontSize: 12, color: _onSurface.withOpacity(0.8)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _keyController,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            style: TextStyle(color: _onSurface, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'مثلاً: a1b2c3d4e5',
              hintStyle:
                  TextStyle(color: _onSurface.withOpacity(0.35), fontSize: 12),
              prefixIcon:
                  const Icon(Icons.key_outlined, color: AppTheme.pink),
              filled: true,
              fillColor: _onSurface.withOpacity(0.05),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.pink.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.pink.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.pink, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _saveKey,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.pink,
              foregroundColor: const Color(0xFF2B0A1B),
            ),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('ذخیره و دریافت قیمت‌ها'),
          ),
        ],
      ),
    );
  }

  /// انتخاب یک گزینه
  Future<void> _onSelect(SourceOption option) async {
    final PricesProvider prices = widget.prices;

    // منبع کلیددار: فقط فیلد کلید باز/بسته شود؛ تغییر با دکمه ذخیره انجام می‌شود
    if (option.requiresKey) {
      setState(() => _expandedId =
          (_expandedId == option.id) ? null : option.id);
      return;
    }

    if (prices.sourceId == option.id) {
      // همین منبع فعال است
      Navigator.of(context).pop();
      return;
    }

    // پیام‌رسان صفحه اصلی قبل از بستن شیت گرفته می‌شود
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    await prices.switchSource(option.id);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.pink,
        content: Text(
          'منبع داده به «${option.name}» تغییر کرد.',
          style: const TextStyle(
            color: Color(0xFF2B0A1B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  /// ذخیره کلید API و دریافت مجدد قیمت‌ها
  Future<void> _saveKey() async {
    final PricesProvider prices = widget.prices;
    final String key = _keyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('اول کلید API را وارد کنید.'),
        ),
      );
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    // اگر منبع کلیددار فعال نیست، اول به آن منتقل شو
    if (!prices.sourceRequiresKey) {
      Navigator.of(context).pop();
      await prices.switchSource('talaapi', apiKey: key);
    } else {
      Navigator.of(context).pop();
      await prices.saveApiKey(key);
    }

    messenger.showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.pink,
        content: Text(
          'کلید API ذخیره شد؛ در حال دریافت قیمت‌ها…',
          style: TextStyle(
            color: Color(0xFF2B0A1B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
