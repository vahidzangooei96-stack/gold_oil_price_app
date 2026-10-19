/// خطای سطح اپلیکیشن همراه با پیام فارسی، آماده برای نمایش به کاربر
class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
