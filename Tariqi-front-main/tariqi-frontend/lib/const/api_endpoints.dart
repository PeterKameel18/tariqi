// lib/const/api_endpoints.dart
class ApiEndpoints {
  static const String baseUrl = 'http://tariqi.zapto.org/api';
  
  // Auth endpoints
  static const String login = '$baseUrl/auth/login';
  static const String signup = '$baseUrl/auth/signup';

  // Driver endpoints
  static const String driverProfile = '$baseUrl/driver/get/info';  // Make sure this matches Postman
  static const String driverStartRide = '$baseUrl/driver/create/ride';
  static const String driverEndRide = '$baseUrl/driver/end/ride'; // Append ride_id when calling
  static const String driverEndClientRide = '$baseUrl/driver/end/client/ride'; // Append ride_id and client_id when calling
  static const String driverAcceptRequest = '$baseUrl/driver/accept-request';
  static const String driverDeclineRequest = '$baseUrl/driver/decline-request';
  
  // Join request endpoints
  static const String joinRequestsPending = '$baseUrl/joinRequests/pending'; // Append ride_id when calling
  static const String joinRequestApprove = '$baseUrl/joinRequests'; // Append /{request_id}/approve when calling
  static const String joinRequestPickup = '$baseUrl/joinRequests'; // Append /{request_id}/pickup when calling
  static const String joinRequestDropoff = '$baseUrl/joinRequests'; // Append /{request_id}/dropoff when calling

  // User endpoints
  static const String userGetPendingRequests = '$baseUrl/user/get/pending/requests'; // Append ride_id when calling
  static const String userRespondToRequest = '$baseUrl/user/respond/to/request'; // Append ride_id when calling
  static const String userSetLocation = '$baseUrl/user/set/location';
  static const String userGetRideData = '$baseUrl/user/get/ride/data'; // Append ride_id when calling

}