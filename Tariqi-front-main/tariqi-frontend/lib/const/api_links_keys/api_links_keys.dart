import 'package:tariqi/const/secrets.dart';

class ApiLinksKeys {
  static const String baseUrl = "http://192.168.1.44:3000/api";
  static String geoCodingKey = Secrets.openCageGeocodingKey;
  static const String clientSignupUrl = "$baseUrl/auth/signup";
  static const String driverSignupUrl = "$baseUrl/auth/signup";
}
