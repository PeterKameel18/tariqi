/// Single source of truth for backend API configuration.
/// Change [baseUrl] when switching between dev / staging / production.
abstract class AppConfig {
  static const String baseUrl = 'https://tariqi-app-4jb25.ondigitalocean.app/api';

  static const String socketUrl = 'https://tariqi-app-4jb25.ondigitalocean.app';
}
