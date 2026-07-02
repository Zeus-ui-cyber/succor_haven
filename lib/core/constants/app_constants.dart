// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // Default base URL — override at startup via configure() if you pass
  // --dart-define=API_URL=... or read it from somewhere at runtime.
  static String baseUrl = 'http://localhost:3000/api';

  static const String accessTokenKey = 'sh_access_token';
  static const String refreshTokenKey = 'sh_refresh_token';

  /// Call this once, early in main(), if you need to override baseUrl
  /// at runtime (e.g. from a --dart-define or platform check).
  static void configure({required String url}) {
    baseUrl = url;
  }
}