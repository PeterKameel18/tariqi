import 'package:tariqi/const/app_config.dart';

class ApiEndpoints {
  static const String baseUrl = AppConfig.baseUrl;

  // Auth endpoints
  static const String login = '$baseUrl/auth/login';
  static const String signup = '$baseUrl/auth/signup';

  // Driver endpoints
  static const String driverProfile = '$baseUrl/driver/get/info';
  static const String driverStartRide = '$baseUrl/driver/create/ride';
  static const String driverEndRide = '$baseUrl/driver/end/ride';
  static const String driverEndClientRide = '$baseUrl/driver/end/client/ride';
  static const String driverAcceptRequest = '$baseUrl/driver/accept-request';
  static const String driverDeclineRequest = '$baseUrl/driver/decline-request';

  // Join request endpoints
  static const String joinRequestsPending = '$baseUrl/joinRequests/pending';
  static const String joinRequestApprove = '$baseUrl/joinRequests';
  static const String joinRequestPickup = '$baseUrl/joinRequests';
  static const String joinRequestDropoff = '$baseUrl/joinRequests';

  // User endpoints
  static const String userGetPendingRequests = '$baseUrl/user/get/pending/requests';
  static const String userRespondToRequest = '$baseUrl/user/respond/to/request';
  static const String userSetLocation = '$baseUrl/user/set/location';
  static const String userGetRideData = '$baseUrl/user/get/ride/data';
}
