// lib/services/driver/driver_service.dart
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:tariqi/const/api_endpoints.dart';
import 'package:tariqi/controller/auth_controllers/auth_controller.dart';
import 'package:tariqi/controller/driver/driver_home_controller.dart';

import '../controller/driver/driver_active_ride_controller.dart';
import 'package:http/http.dart' as http;
import 'package:tariqi/models/app_notification.dart';
import 'package:tariqi/models/chat_message.dart';

class DriverService extends GetConnect {
  String? currentRideId;
  
  Future<Map<String, dynamic>> getDriverProfile() async {
    // Use the API endpoints constant instead of hardcoding the URL
    final exactUrl = ApiEndpoints.driverProfile;
    log("📥 Fetching driver profile from EXACT URL: $exactUrl");
    
    // First, explicitly refresh the token
    final authController = Get.find<AuthController>();
    await authController.loadToken();
    final token = authController.token.value;
    
    // Format the authorization header exactly as needed
    final authHeader = 'Bearer $token';
    log("🔒 EXACT AUTH HEADER: '$authHeader'");
    
    try {
      // Make sure we have a token before proceeding
      if (token.isEmpty) {
        throw Exception('No authentication token available');
      }
      
      // Create headers with exact format
      final headers = {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
      };
      log("🔑 EXACT HEADERS: $headers");
      
      // Try with exact format as seen in Postman
      final response = await http.get(
        Uri.parse(exactUrl),
        headers: headers,
      );

      log("📤 Profile response status: ${response.statusCode}");
      log("📤 Full profile response: ${response.body}");
      
      if (response.statusCode != 200) {
        log("❌ Profile error: ${response.statusCode}");
        
        // Handle specific error cases
        if (response.statusCode == 401) {
          // Token is invalid or expired, try to re-authenticate
          throw Exception('Authentication failed, please log in again');
        }
        
        throw Exception('Failed to fetch driver profile: ${response.body}');
      }
      
      // Check if response is valid
      if (response.body.isEmpty) {
        log("⚠️ Server returned empty body, using fallback data");
        // Return fallback data if server returns null
        return {
          'email': 'driver@example.com',
          'profilePic': '',
          'carDetails': {
            'make': 'Toyota',
            'model': 'Camry',
            'licensePlate': 'ABC-1234'
          },
          'drivingLicense': 'DL-12345678'
        };
      }
      
      // Parse JSON response
      try {
        final Map<String, dynamic> parsedBody = jsonDecode(response.body);
        
        // Extract user data from the nested structure
        if (parsedBody.containsKey('user')) {
          log("✅ Found 'user' field in response, extracting data");
          final userData = parsedBody['user'] as Map<String, dynamic>;
          
          // Map the API response fields to match what the UI expects
          return {
            'email': userData['email'] ?? 'No Email',
            'profilePic': userData['profilePic'] ?? '',
            'firstName': userData['firstName'] ?? '',
            'lastName': userData['lastName'] ?? '',
            'phoneNumber': userData['phoneNumber'] ?? '',
            'carDetails': userData['carDetails'] ?? {
              'make': 'Unknown',
              'model': 'Unknown',
              'licensePlate': 'No Plate'
            },
            'drivingLicense': userData['drivingLicense'] ?? 'No License'
          };
        } else {
          log("⚠️ Response doesn't contain 'user' field: $parsedBody");
          return parsedBody; // Return as is, will likely trigger fallback values
        }
      } catch (e) {
        log("⚠️ Failed to parse JSON: $e");
        // Return fallback data
        return {
          'email': 'driver@example.com',
          'profilePic': '',
          'carDetails': {
            'make': 'Toyota',
            'model': 'Camry',
            'licensePlate': 'ABC-1234'
          },
          'drivingLicense': 'DL-12345678'
        };
      }
    } catch (e) {
      log("❌ Profile exception: $e");
      // Still return fallback data on error for UI testing
      return {
        'email': 'driver@example.com',
        'profilePic': '',
        'carDetails': {
          'make': 'Toyota',
          'model': 'Camry',
          'licensePlate': 'ABC-1234'
        },
        'drivingLicense': 'DL-12345678'
      };
    }
  }

  Future<Map<String, dynamic>> startRide({
    required LatLng startLocation,
    required String destination,
    required int maxPassengers,
  }) async {
    // Clear any existing ride ID first to avoid conflicts
    currentRideId = null;
    
    final token = Get.find<AuthController>().token.value;
    if (token.isEmpty) {
      throw Exception('No authentication token available');
    }
    
    // Format the authorization header exactly
    final authHeader = 'Bearer $token';
    log("🔒 EXACT AUTH HEADER FOR RIDE CREATION: '$authHeader'");
    
    // Check for invalid coordinates
    if (startLocation.latitude == 0 || startLocation.longitude == 0 ||
        endLat == 0 || endLong == 0) {
      log("⚠️ WARNING: Invalid coordinates detected!");
      log("⚠️ startLocation: $startLocation");
      log("⚠️ endLocation: [$endLat, $endLong]");
    }
    
    // Setting up detailed logging for debugging
    log("🧰 DEBUG: Creating ride with the following params:");
    log("🧰 Start location: ${startLocation.latitude}, ${startLocation.longitude}");
    log("🧰 End location: $endLat, $endLong");
    log("🧰 Destination text: $destination");
    log("🧰 Max passengers: $maxPassengers");
    
    final body = {
      "route": [
        { "lat": startLocation.latitude, "lng": startLocation.longitude },  // Driver Pickup
        { "lat": endLat, "lng": endLong }   // Driver Dropoff
      ],
      "availableSeats": maxPassengers
    };

    // Use the API endpoints class instead of hardcoding
    final exactUrl = ApiEndpoints.driverStartRide;
    log("🚀 Starting ride with body: $body");
    log("🚀 Using EXACT URL: $exactUrl");
    
    // Convert body to JSON string and log it
    final jsonBody = jsonEncode(body);
    log("📦 EXACT REQUEST BODY: $jsonBody");

    try {
      // Create headers with exact format
      final headers = {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
      };
      log("🔑 EXACT HEADERS FOR RIDE: $headers");
      
      // Now try the actual ride creation with a more explicitly formatted Authorization header
      final response = await http.post(
        Uri.parse(exactUrl),
        headers: headers,
        body: jsonBody,
      );

      log("← Response status code: ${response.statusCode}");
      log("← Full response headers: ${response.headers}");
      log("← Full response body: ${response.body}"); // Log full response for debugging
      
      if (response.statusCode >= 400) {
        log("❌ API error: ${response.statusCode}");
        log("❌ API error response: ${response.body}");
        throw Exception('Failed to start ride: ${response.body}');
      }
      
      // Parse the response JSON
      try {
        final Map<String, dynamic> parsedBody = jsonDecode(response.body);
        log("👀 FULL PARSED RESPONSE: $parsedBody");
        
        String? extractedRideId;
        
        // Try multiple approaches to extract the ride ID
        
        // Approach 1: Check for 'ride._id' structure
        if (parsedBody.containsKey("ride") && parsedBody["ride"] is Map) {
          final rideData = parsedBody["ride"] as Map<String, dynamic>;
          if (rideData.containsKey("_id")) {
            extractedRideId = rideData["_id"].toString();
            log("✅ Found ride ID in response (approach 1): $extractedRideId");
          }
        } 
        
        // Approach 2: Check for 'rideId' field
        if (extractedRideId == null && parsedBody.containsKey("rideId")) {
          extractedRideId = parsedBody["rideId"].toString();
          log("✅ Found ride ID in response (approach 2): $extractedRideId");
        }
        
        // Approach 3: Check for '_id' field directly
        if (extractedRideId == null && parsedBody.containsKey("_id")) {
          extractedRideId = parsedBody["_id"].toString();
          log("✅ Found ride ID in response (approach 3): $extractedRideId");
        }
        
        // Approach 4: Check for 'id' field
        if (extractedRideId == null && parsedBody.containsKey("id")) {
          extractedRideId = parsedBody["id"].toString();
          log("✅ Found ride ID in response (approach 4): $extractedRideId");
        }
        
        // Store the extracted ride ID
        if (extractedRideId != null && extractedRideId.isNotEmpty) {
          currentRideId = extractedRideId;
          log("✅ STORED RIDE ID: $currentRideId");
        } else {
          log("⚠️ Failed to extract ride ID from response");
        }
        
        // Ensure routes is properly assigned as an RxList
        final routeData = parsedBody.containsKey("ride") && parsedBody["ride"] is Map ? 
            (parsedBody["ride"] as Map<String, dynamic>)["route"] : null;
            
        routes.clear();
        
        if (routeData != null && routeData is List) {
          routes.addAll(routeData.cast<Map<String, dynamic>>());
          log("✅ Routes data assigned: $routes");
        } else {
          log("⚠️ No route data in response, creating fallback");
          routes.add({"lat": startLocation.latitude, "lng": startLocation.longitude});
          routes.add({"lat": endLat, "lng": endLong});
        }
        
        return parsedBody;
      } catch (e) {
        log("❌ Failed to parse response: $e");
        throw Exception('Failed to parse response: $e');
      }
    } catch (e) {
      log("❌ Start ride exception: $e");
      rethrow;
    }
  }

  Future<void> endAllActiveRides() async {
    final token = Get.find<AuthController>().token.value;
    if (token.isEmpty) {
      log("⚠️ No token available to end rides");
      return;
    }
    
    // Check if we have an active ride to end
    if (currentRideId != null && currentRideId!.isNotEmpty) {
      log("🛑 Ending active ride: $currentRideId");
      await endRide(currentRideId!);
    } else {
      log("ℹ️ No active ride to end");
    }
  }

  Future<bool> endRide(String rideId) async {
    try {
      log("📤 Attempting to end ride with ID: $rideId");
      
      final authController = Get.find<AuthController>();
      final token = authController.token.value;
      
      // Use the dedicated endpoint from ApiEndpoints
      final url = "${ApiEndpoints.baseUrl}/driver/ride/$rideId/end";
      log("📤 End ride URL: $url");
      
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
      );
      
      log("📥 End ride response: [${response.statusCode}]");
      log("📥 Response body: ${response.body}");
      
      if (response.statusCode != 200) {
        log("❌ Failed to end ride. Status: ${response.statusCode}, Body: ${response.body}");
      }
      
      // Clear the current ride ID if successful
      if (response.statusCode == 200) {
        currentRideId = null;
        // Clear saved passengers for this ride
        await clearSavedPassengers(rideId);
      }
      
      return response.statusCode == 200;
    } catch (e) {
      log("❌ Exception in endRide: $e");
      return false;
    }
  }

  Future<bool> endClientRide(String rideId, String clientId) async {
    try {
      final authController = Get.find<AuthController>();
      final response = await http.post(
        Uri.parse("${ApiEndpoints.baseUrl}/driver/end/client/ride/$rideId/$clientId"),
        headers: {
          'Authorization': 'Bearer ${authController.token.value}',
          'Content-Type': 'application/json',
        },
      );
      
      log("🛑 End client ride response: ${response.statusCode}");
      
      return response.statusCode == 200;
    } catch (e) {
      log("❌ Error ending client ride: $e");
      return false;
    }
  }

  Future<List<dynamic>> getPendingRequests(String rideId) async {
    int retryCount = 0;
    const maxRetries = 2;
    const initialDelayMs = 1000;
    
    Future<List<dynamic>> attemptRequest() async {
      try {
        final authController = Get.find<AuthController>();
        final token = authController.token.value;
        
        // Log useful debugging information
        final url = "${ApiEndpoints.joinRequestsPending}/$rideId";
        log("📤 Fetching pending requests URL: $url");
        
        final headers = {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        };
        
        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        );
        
        log("📥 Pending requests response status: ${response.statusCode}");
        
        // Only log full response for smaller responses to avoid console flooding
        if (response.body.length < 1000) {
          log("📥 Pending requests response body: ${response.body}");
        } else {
          log("📥 Pending requests response body too large to log (${response.body.length} bytes)");
        }
        
        if (response.statusCode == 200) {
          try {
            final data = jsonDecode(response.body);
            if (data is List) {
              log("✅ Received list of pending requests: ${data.length} requests");
              return data;
            } else if (data is Map && data.containsKey('requests')) {
              log("✅ Received map with requests field: ${data['requests']?.length ?? 0} requests");
              return data['requests'] ?? [];
            } else {
              log("⚠️ Unexpected response format: $data");
              return [];
            }
          } catch (e) {
            log("⚠️ JSON parse error: $e");
            return [];
          }
        } else if (response.statusCode == 502) {
          // 502 Bad Gateway - server issue
          throw Exception("Server temporarily unavailable (502). This is a server-side issue.");
        } else if (response.statusCode >= 500) {
          // Other 5xx server errors
          throw Exception("Server error (${response.statusCode}). Please try again later.");
        } else if (response.statusCode == 404) {
          // 404 Not Found - no pending requests or wrong endpoint
          log("ℹ️ No pending requests found (404): ${response.body}");
          return [];
        } else if (response.statusCode == 401) {
          // 401 Unauthorized - auth issue
          log("⚠️ Authentication error (401): ${response.body}");
          return [];
        } else {
          // Any other status code
          log("❌ Failed to get pending requests: ${response.statusCode} - ${response.body}");
          return [];
        }
      } catch (e) {
        log("❌ Error getting pending requests: $e");
        rethrow; // Rethrow for retry logic
      }
    }
    
    // Main execution with retry logic
    while (retryCount <= maxRetries) {
      try {
        return await attemptRequest();
      } catch (e) {
        retryCount++;
        
        if (retryCount > maxRetries) {
          log("❌ All retry attempts failed for getPendingRequests");
          return []; // Return empty list after all retries failed
        }
        
        // Exponential backoff: 1s, 2s, 4s, etc.
        final delayMs = initialDelayMs * math.pow(2, retryCount - 1).toInt();
        log("⏳ Retry $retryCount after $delayMs ms");
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    
    return []; // Fallback return if loop exits unexpectedly
  }

  Future<bool> acceptRideRequest(String requestId) async {
    try {
      final authController = Get.find<AuthController>();
      final response = await http.post(
        Uri.parse("${ApiEndpoints.baseUrl}/driver/accept/request/$requestId"),
        headers: {
          'Authorization': 'Bearer ${authController.token.value}',
          'Content-Type': 'application/json',
        },
      );
      
      log("🛑 Accept request response: ${response.statusCode}");
      
      return response.statusCode == 200;
    } catch (e) {
      log("❌ Error accepting request: $e");
      return false;
    }
  }

  Future<bool> declineRideRequest(String requestId) async {
    try {
      final authController = Get.find<AuthController>();
      final response = await http.post(
        Uri.parse("${ApiEndpoints.baseUrl}/driver/decline/request/$requestId"),
        headers: {
          'Authorization': 'Bearer ${authController.token.value}',
          'Content-Type': 'application/json',
        },
      );
      
      log("🛑 Decline request response: ${response.statusCode}");
      
      return response.statusCode == 200;
    } catch (e) {
      log("❌ Error declining request: $e");
      return false;
    }
  }

  // Check if there's an active ride for the driver
  Future<bool> hasActiveRide() async {
    try {
      // Skip if no auth token
      final authController = Get.find<AuthController>();
      if (authController.token.value.isEmpty) {
        log("❌ No auth token available");
        return false;
      }
      
      // If we already have a stored ride ID, check if it's still active
      if (currentRideId != null && currentRideId!.isNotEmpty) {
        log("🔍 Checking if stored ride ID is still active: $currentRideId");
        
        // Call API to check if this ride is still active
        final response = await http.get(
          Uri.parse("${ApiEndpoints.baseUrl}/user/get/ride/data/$currentRideId"),
          headers: {
            'Authorization': 'Bearer ${authController.token.value}',
            'Content-Type': 'application/json',
          },
        );
        
        if (response.statusCode == 200) {
          log("✅ Ride is still active");
          return true;
        } else {
          log("⚠️ Stored ride is no longer active, clearing ID");
          currentRideId = null;
        }
      }
      
      // First, try with driver profile info which contains inRide field
      try {
        final profileResponse = await http.get(
          Uri.parse(ApiEndpoints.driverProfile),
          headers: {
            'Authorization': 'Bearer ${authController.token.value}',
            'Content-Type': 'application/json',
          },
        );
        
        if (profileResponse.statusCode == 200) {
          final data = jsonDecode(profileResponse.body);
          if (data.containsKey('user') && 
              data['user'] is Map && 
              data['user'].containsKey('inRide') && 
              data['user']['inRide'] != null) {
            
            currentRideId = data['user']['inRide'].toString();
            log("✅ Found active ride from driver profile: $currentRideId");
            return true;
          }
        }
      } catch (e) {
        log("⚠️ Error checking driver profile: $e");
      }
      
      // No active ride found in profile, or API call failed
      currentRideId = null;
      return false;
    } catch (e) {
      log("❌ Error checking for active ride: $e");
      return false;
    }
  }

  // Get ride data by ID (with multiple endpoint attempts)
  Future<Map<String, dynamic>?> getRideData(String rideId) async {
    if (rideId.isEmpty) {
      log("❌ Cannot get ride data: Empty ride ID");
      return null;
    }
    
    final authController = Get.find<AuthController>();
    final token = authController.token.value;
    
    if (token.isEmpty) {
      log("❌ Cannot get ride data: No auth token");
      return null;
    }
    
    // Use the correct endpoint based on the API design
    final endpoint = "${ApiEndpoints.baseUrl}/user/get/ride/data/$rideId";
    try {
      log("🔍 Using API endpoint for ride data: $endpoint");
      
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      log("🔍 Endpoint response: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        log("✅ Successful response from: $endpoint");
        
        // Extract the ride data based on response format
        if (data.containsKey('ride')) {
          return data['ride'];
        } else {
          return data;
        }
      } else {
        log("⚠️ Failed to get ride data: ${response.statusCode}");
        
        // If this is a 404, the ride might not exist anymore
        if (response.statusCode == 404) {
          currentRideId = null;
        }
      }
    } catch (e) {
      log("⚠️ Error trying endpoint $endpoint: $e");
    }
    
    // If the main endpoint failed, try the driver profile as fallback
    try {
      log("🔍 Trying driver profile endpoint as fallback");
      final profileResponse = await http.get(
        Uri.parse(ApiEndpoints.driverProfile),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (profileResponse.statusCode == 200) {
        final data = jsonDecode(profileResponse.body);
        
        if (data.containsKey('user') && 
            data['user'] is Map &&
            data['user'].containsKey('inRide') && 
            data['user']['inRide'] != null) {
          
          final foundRideId = data['user']['inRide'].toString();
          
          // If the found ID matches our requested ID, we know it exists
          // but we couldn't get details - return basic info
          if (foundRideId == rideId) {
            log("✅ Found ride ID in profile, but could not get details");
            return {
              '_id': rideId,
              'driver': data['user']['_id'] ?? '',
              'status': 'active',
              'routes': []
            };
          }
          // If we found a different ID, update our current ID and try to get that ride
          else if (foundRideId.isNotEmpty) {
            log("🔄 Found different ride ID in profile, updating: $foundRideId");
            currentRideId = foundRideId;
            // Try again with the new ID
            return await getRideData(foundRideId);
          }
        }
      }
    } catch (e) {
      log("⚠️ Error with fallback: $e");
    }
    
    log("❌ All endpoints failed for ride ID: $rideId");
    return null;
  }

  Future<bool> approveJoinRequest(String requestId, bool approved) async {
    try {
      // Log the request information for debugging
      log("📤 Attempting to ${approved ? 'approve' : 'decline'} join request with ID: $requestId");
      
      final authController = Get.find<AuthController>();
      final token = authController.token.value;
      
      // Use the dedicated endpoint from ApiEndpoints
      final url = "${ApiEndpoints.joinRequestApprove}/$requestId/approve";
      log("📤 Request URL: $url");
      
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      log("📤 Headers: $headers");
      
      final body = {"approved": approved};
      log("📤 Request body: $body");
      
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );
      
      // Log the complete response
      log("📥 Approve join request response status: [${response.statusCode}]");
      log("📥 Response body: ${response.body}");
      
      // Check the specific error case
      if (response.statusCode != 200) {
        log("❌ Failed to ${approved ? 'approve' : 'decline'} request. Status: ${response.statusCode}, Body: ${response.body}");
        // If there's a specific error message in the response, log it
        try {
          final errorData = jsonDecode(response.body);
          if (errorData.containsKey('message')) {
            log("❌ Server error message: ${errorData['message']}");
          }
        } catch (e) {
          // Ignore JSON parse errors
        }
      }
      
      return response.statusCode == 200;
    } catch (e) {
      log("❌ Exception in approveJoinRequest: $e");
      return false;
    }
  }

  Future<bool> pickupPassenger(String requestId) async {
    try {
      log("📤 Attempting to pickup passenger with request ID: $requestId");
      
      final authController = Get.find<AuthController>();
      final token = authController.token.value;
      
      // Use the dedicated endpoint from ApiEndpoints
      final url = "${ApiEndpoints.joinRequestPickup}/$requestId/pickup";
      log("📤 Pickup URL: $url");
      
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
      );
      
      log("📥 Pickup passenger response: [${response.statusCode}]");
      log("📥 Response body: ${response.body}");
      
      if (response.statusCode != 200) {
        log("❌ Failed to pickup passenger. Status: ${response.statusCode}, Body: ${response.body}");
      }
      
      return response.statusCode == 200;
    } catch (e) {
      log("❌ Exception in pickupPassenger: $e");
      return false;
    }
  }

  Future<bool> dropoffPassenger(String requestId) async {
    try {
      log("📤 Attempting to dropoff passenger with request ID: $requestId");
      
      final authController = Get.find<AuthController>();
      final token = authController.token.value;
      
      // Use the dedicated endpoint from ApiEndpoints
      final url = "${ApiEndpoints.joinRequestDropoff}/$requestId/dropoff";
      log("📤 Dropoff URL: $url");
      
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
      );
      
      log("📥 Dropoff passenger response: [${response.statusCode}]");
      log("📥 Response body: ${response.body}");
      
      if (response.statusCode != 200) {
        log("❌ Failed to dropoff passenger. Status: ${response.statusCode}, Body: ${response.body}");
      }
      
      return response.statusCode == 200;
    } catch (e) {
      log("❌ Exception in dropoffPassenger: $e");
      return false;
    }
  }

  // Use a Map to store passengers data in memory for persistence between screens
  // This allows the data to persist during the app's lifecycle
  final Map<String, List<Map<String, dynamic>>> _savedPassengersByRideId = {};
  
  // Save passengers data for a specific ride
  Future<void> savePassengers(String rideId, List<Map<String, dynamic>> passengers) async {
    try {
      log("💾 Saving ${passengers.length} passengers for ride $rideId");
      _savedPassengersByRideId[rideId] = List.from(passengers);
    } catch (e) {
      log("❌ Error saving passengers: $e");
    }
  }
  
  // Get saved passengers data for a ride
  Future<List<Map<String, dynamic>>?> getSavedPassengers(String rideId) async {
    try {
      if (_savedPassengersByRideId.containsKey(rideId)) {
        final savedPassengers = _savedPassengersByRideId[rideId];
        log("📤 Retrieved ${savedPassengers?.length ?? 0} saved passengers for ride $rideId");
        return savedPassengers != null ? List.from(savedPassengers) : null;
      }
      log("ℹ️ No saved passengers found for ride $rideId");
      return null;
    } catch (e) {
      log("❌ Error getting saved passengers: $e");
      return null;
    }
  }
  
  // Clear saved passengers data for a ride
  Future<void> clearSavedPassengers(String rideId) async {
    try {
      if (_savedPassengersByRideId.containsKey(rideId)) {
        _savedPassengersByRideId.remove(rideId);
        log("🧹 Cleared saved passengers for ride $rideId");
      }
    } catch (e) {
      log("❌ Error clearing saved passengers: $e");
    }
  }
}

class NotificationService {
  static const String baseUrl = ApiEndpoints.baseUrl;

  static Future<List<AppNotification>> fetchNotifications(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((n) => AppNotification.fromJson(n)).toList();
    }
    throw Exception('Failed to fetch notifications');
  }

  static Future<void> sendNotification(String token, Map<String, dynamic> payload) async {
    await http.post(
      Uri.parse('$baseUrl/notifications'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );
  }
}

class ChatService {
  static const String baseUrl = ApiEndpoints.baseUrl;

  static Future<void> createChatRoom(String token, String rideId) async {
    await http.post(
      Uri.parse('$baseUrl/chat/$rideId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }

  static Future<List<ChatMessage>> fetchMessages(String token, String rideId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/$rideId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      log('🟦 Chat fetch response (${response.statusCode}): ${response.body}');
      if (response.statusCode == 200) {
        try {
          final List data = jsonDecode(response.body);
          log('🟦 Chat parsed messages: $data');
          return data.map((m) => ChatMessage.fromJson(m)).toList();
        } catch (e) {
          log('Error parsing chat messages: $e');
          // If we can't parse the response as a list, return an empty list
          return [];
        }
      } else if (response.statusCode == 404) {
        // Chat room not found, return empty list
        log('Chat room not found for ride $rideId');
        return [];
      } else if (response.statusCode == 500) {
        // Server error, log it but return empty list to prevent app crashes
        log('Server error when fetching messages: ${response.body}');
        return [];
      }
      // For other status codes, throw exception
      throw Exception('Failed to fetch chat messages: ${response.statusCode}');
    } catch (e) {
      log('Error in fetchMessages: $e');
      // Return empty list rather than throwing to prevent app crashes
      return [];
    }
  }

  static Future<void> sendMessage(String token, String rideId, String message) async {
    try {
      // Try to get driver name first
      String driverName = 'Driver'; // Default fallback
      try {
        final driverService = Get.find<DriverService>();
        final profile = await driverService.getDriverProfile();
        final firstName = profile['firstName'] ?? '';
        final lastName = profile['lastName'] ?? '';
        final fullName = '$firstName $lastName'.trim();
        if (fullName.isNotEmpty) {
          driverName = fullName;
        }
      } catch (e) {
        log('⚠️ Could not get driver name for chat: $e');
      }
      
      // Send message with the driver name included
      final response = await http.post(
        Uri.parse('$baseUrl/chat/$rideId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'content': message,
          'senderName': driverName, // Include sender name in request
        }),
      );
      
      log('🟧 Chat send response (${response.statusCode}): ${response.body}');
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to send message: ${response.body}');
      }
    } catch (e) {
      log('❌ Error sending message: $e');
      rethrow;
    }
  }
}