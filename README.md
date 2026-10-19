# قیمت لحظه‌ای طلا و نفت برنت — Flutter

اپلیکیشن اندرویدی ساخته‌شده با **Flutter** و **Material 3** برای نمایش لحظه‌ای:

- قیمت انس طلا (XAU/USD) به دلار
- قیمت نفت برنت (Brent Crude) به دلار در هر بشکه

## ویژگی‌ها

- دو کارت بزرگ و مدرن برای طلا و نفت با پس‌زمینه گرادیانی
- فونت بزرگ و خوانا برای قیمت‌ها + ارقام فارسی با جداکننده هزارگان (۲٬۶۵۰٫۳۵)
- نمایش واحد قیمت زیر هر عدد (دلار برای هر اونس / دلار برای هر بشکه)
- نمایش زمان آخرین بروزرسانی موفق
- آپدیت خودکار قیمت‌ها هر ۳۰ ثانیه
- دکمه رفرش دستی در AppBar و Pull-to-Refresh
- نمایش وضعیت بارگذاری (Loading) و پیام خطای فارسی هنگام قطع اینترنت
- بنر هشدار ملایم وقتی آپدیت جدید شکست می‌خورد ولی داده‌های قبلی موجودند
- نشان افزایش/کاهش قیمت نسبت به دریافت قبلی (سبز/قرمز)
- پشتیبانی کامل Dark Mode + سوییچ پوسته (سیستم / تاریک / روشن)
- طراحی ریسپانسیو: کارت‌ها در تبلت و حالت افقی کنار هم قرار می‌گیرند
- Material 3 + فونت فارسی وزیرمتن + بومی‌سازی کامل پیام‌های Material به فارسی
- مدیریت State با Provider (الگوی ChangeNotifier)
- توقف خودکار آپدیت در پس‌زمینه و ادامه فوری پس از بازگشت (بهینه‌سازی باتری)
- درخواست‌های موازی برای دو منبع؛ شکست یکی، دیگری را خراب نمی‌کند

## ساختار پروژه

```
gold_oil_price_app/
├── pubspec.yaml                    # وابستگی‌ها و تنظیمات فونت
├── analysis_options.yaml           # قواعد Lint
├── .gitignore
├── README.md
├── assets/
│   └── fonts/                      # فونت وزیرمتن (Regular/Medium/Bold + OFL.txt)
├── test/
│   └── widget_test.dart            # تست دود (Smoke Test) صفحه اصلی
└── lib/
    ├── main.dart                   # نقطه ورود، Providerها، تم و لوکال فارسی
    ├── models/
    │   └── price_models.dart       # مدل PriceData
    ├── services/
    │   └── api_service.dart        # دریافت قیمت از دو API
    ├── providers/
    │   ├── prices_provider.dart    # مدیریت State قیمت‌ها + تایمر ۳۰ ثانیه
    │   └── theme_provider.dart     # مدیریت پوسته روشن/تاریک/سیستم
    ├── theme/
    │   └── app_theme.dart          # تم‌های Material 3
    ├── utils/
    │   └── formatters.dart         # ارقام فارسی، جداکننده هزارگان، ساعت
    ├── screens/
    │   └── home_screen.dart        # صفحه اصلی
    └── widgets/
        ├── price_card.dart         # کارت بزرگ قیمت
        └── status_views.dart       # نمای بارگذاری و نمای خطا
```

## معماری

```
UI (HomeScreen / PriceCard)
        │  watch / read
        ▼
PricesProvider (ChangeNotifier)  ←  Timer هر ۳۰ ثانیه + Observer چرخه حیات
        │  fetch (موازی)
        ▼
ApiService (http)  →  xaus.com (طلا)  +  americasoilwatch.com (برنت)
```

- **UI** فقط با `context.watch` وضعیت را می‌خواند و با `context.read` اکشن صادر می‌کند.
- **PricesProvider** وضعیت (قیمت‌ها، بارگذاری، خطا، زمان آخرین بروزرسانی) را نگه می‌دارد؛
  درخواست‌های موازی با `Future.wait` ارسال می‌شوند و خطای هر منبع جدا مهار می‌شود.
- **ApiService** فقط کار شبکه و پارس JSON را انجام می‌دهد و پیام‌های خطای فارسی تولید می‌کند.

## پیش‌نیازها

- Flutter SDK نسخه ۳.۲۴ یا بالاتر (Dart 3)
- Android SDK / Android Studio برای بیلد اندروید

## راه‌اندازی

```bash
git clone https://github.com/vahidzangooei96-stack/gold_oil_price_app.git
cd gold_oil_price_app

# فقط بار اول: تولید پوشه‌های پلتفرمی (android/ ، ios/ و ...) از روی pubspec موجود
flutter create .

# نصب وابستگی‌ها
flutter pub get

# اجرا روی دستگاه یا شبیه‌ساز
flutter run
```

اگر `flutter create .` درباره نام پکیج خطا داد، از دستور زیر استفاده کنید:

```bash
flutter create . --project-name gold_oil_price
```

## مجوز اینترنت (مهم برای نسخه Release)

در فایل `android/app/src/main/AndroidManifest.xml` این خط را داخل تگ `<manifest>`
(بالای `<application>`) اضافه کنید:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

در حالت Debug این مجوز به‌صورت پیش‌فرض وجود دارد، اما برای خروجی Release لازم است.

## تغییر نام نمایشی اپ (اختیاری)

در همان فایل، روی تگ `<application>` مقدار `android:label` را به دلخواه تغییر دهید؛
مثلاً: `android:label="قیمت طلا و نفت"`.

## بیلد خروجی Release

```bash
flutter build apk --release
# مسیر خروجی: build/app/outputs/flutter-apk/app-release.apk
```

## اجرای تست‌ها

```bash
flutter test
```

## منابع قیمت

داده‌ها از endpoint رسمی AJAX صفحه اصلی **tala.ir** خوانده می‌شود:

```
https://www.tala.ir/ajax/price
```

این همان آدرسی است که خود صفحه اصلی tala.ir قیمت‌هایش را از آن پر می‌کند؛
اپلیکیشن قیمت‌های زیر را نمایش می‌دهد (همان جعبه‌های صفحه اصلی سایت):

اونس طلا (دلار) | مثقال ۱۷ | طلای ۱۸ عیار | طلای ۲۴ عیار | سکه امامی |
نیم سکه | ربع سکه | سکه گرمی | ارزش طلای سکه | نفت برنت (دلار) | نقره جهانی (دلار)

> چون tala.ir یک سایت ایرانی است، این اپ داخل ایران بدون محدودیت کار می‌کند.

## تم فانتزی

- پس‌زمینه گرادیانی صورتی ↔ آبی (حالت روشن) و بنفش شبانه (حالت تاریک)
- بنر تصویری شخصیت‌های فانتزی اگری و الاغ (تولیدشده با هوش مصنوعی، در `assets/images`)
- کارت‌های حبابی گرد با حاشیه صورتی/آبی متناوب

## شخصی‌سازی

- **رنگ اصلی اپ**: `lib/theme/app_theme.dart` → `seedColor`
- **فاصله آپدیت خودکار**: `lib/providers/prices_provider.dart` → `autoRefreshInterval`
- **فونت**: فایل‌های پوشه `assets/fonts` (وزیرمتن — مجوز OFL در همان پوشه موجود است)
- **زمان تایم‌اوت درخواست‌ها**: `lib/services/api_service.dart` → `_timeout`
