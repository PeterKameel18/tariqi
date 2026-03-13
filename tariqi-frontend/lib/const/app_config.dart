/// Single source of truth for backend API configuration.
/// Change [baseUrl] when switching between dev / staging / production.
abstract class AppConfig {
  // Local development (localhost works for iOS Simulator, use IP for physical device)
  static const String baseUrl = 'http://localhost:3000/api';
  static const String socketUrl = 'http://localhost:3000';

  // Production (uncomment when deploying to DigitalOcean)
  // static const String baseUrl = 'https://tariqi-app-4jb25.ondigitalocean.app/api';
  // static const String socketUrl = 'https://tariqi-app-4jb25.ondigitalocean.app';
}
