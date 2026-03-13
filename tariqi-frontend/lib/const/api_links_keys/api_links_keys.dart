import 'package:tariqi/const/app_config.dart';
import 'package:tariqi/const/secrets.dart';

class ApiLinksKeys {
  static const String baseUrl = AppConfig.baseUrl;
  static String geoCodingKey = Secrets.openCageGeocodingKey;
  static const String clientSignupUrl = "$baseUrl/auth/signup";
  static const String driverSignupUrl = "$baseUrl/auth/signup";
}
