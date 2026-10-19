import 'package:flutter/material.dart';

/// نمای بارگذاری اولیه (وقتی هنوز هیچ داده‌ای دریافت نشده است)
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return _FullPageScrollable(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(strokeWidth: 2.5),
          const SizedBox(height: 20),
          Text(
            'در حال دریافت قیمت‌ها…',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// نمای خطا (وقتی دریافت هر دو نماد ناموفق بوده است)
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  /// پیام خطای فارسی (مثلاً قطع اینترنت)
  final String message;

  /// callback دکمه «تلاش دوباره»
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return _FullPageScrollable(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: scheme.error.withOpacity(0.8),
            ),
            const SizedBox(height: 20),
            Text(
              'خطا در دریافت اطلاعات',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withOpacity(0.7),
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('تلاش دوباره'),
            ),
          ],
        ),
      ),
    );
  }
}

/// قالب مشترک صفحات وضعیت: تمام‌ارتفاع و اسکرول‌پذیر
/// تا Pull-to-Refresh هم روی این صفحات کار کند.
class _FullPageScrollable extends StatelessWidget {
  const _FullPageScrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
