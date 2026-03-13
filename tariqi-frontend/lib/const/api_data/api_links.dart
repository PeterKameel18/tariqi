import 'package:tariqi/const/app_config.dart';

abstract class ApiLinks {
  static const String serverBaseUrl = "${AppConfig.baseUrl}/";

  // Auth End Points
  static const String signupUrl = "auth/signup";
  static const String loginUrl = "auth/login";

  // Client End Points
  static const String clientInfoUrl = "client/get/info";
  static const String clientGetRide = "client/get/rides";
  static const String clientBookRide = "joinRequests/";
  static const String allClientRides = "client/get/all-rides";
  static const String createChatRoom = "chat/";
  static const String notification = "notifications";

  // Driver endpoints
  static const String driverProfile = 'driver/get/info';
  static const String driverStartRide = 'driver/create/ride';
  static const String driverEndRide = 'driver/end/ride';
  static const String driverEndClientRide = 'driver/end/client/ride';
  static const String driverAcceptRequest = 'driver/accept-request';
  static const String driverDeclineRequest = 'driver/decline-request';

  // OSRM Routes End Points
  static const String routesWayUrl =
      "https://router.project-osrm.org/route/v1/driving/";

  // GeoCoding End Points
  static String geoCodebaseUrl = "https://api.opencagedata.com/geocode/v1/json";

  // Payment End Points
  static const paymentBaseUrl = "https://app.fawaterk.com/api/v2/";
  static const String paymentMethodUrl = "invoiceInitPay";
  static const String paymentApiUrl = "getPaymentmethods";
}
