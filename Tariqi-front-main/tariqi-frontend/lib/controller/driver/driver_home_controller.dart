// lib/controller/driver/driver_home_controller.dart
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/services/driver_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:tariqi/const/api_links_keys/api_links_keys.dart';
import 'package:tariqi/controller/auth_controllers/auth_controller.dart';
import 'package:tariqi/view/driver/driver_active_ride_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tariqi/const/secrets.dart';

class DriverHomeController extends GetxController {
  final DriverService _driverService = DriverService();
  final Rx<RequestState> requestState = RequestState.online.obs;
  final RxBool isLocationDisabled = false.obs;
  final RxBool isReadyToStart = false.obs;
  final RxInt maxPassengers = 4.obs;
  
  // Default location coordinates for testing with debugger
  final LatLng defaultLocation = const LatLng(24.7136, 46.6753); // Riyadh, Saudi Arabia
  final RxBool usingDefaultLocation = true.obs;
  
  // Track active ride status
  final RxBool hasActiveRide = false.obs;
  final RxString activeRideId = ''.obs;
  
  // Driver info
  final RxString driverEmail = ''.obs;
  final RxString driverProfilePic = ''.obs;
  final RxString carMake = ''.obs;
  final RxString carModel = ''.obs;
  final RxString licensePlate = ''.obs;
  final RxString drivingLicense = ''.obs;

  // Map controllers
  late MapController mapController;
  LatLng? userPosition;
  final List<Marker> markers = [];
  final List<Polyline> routePolyline = [];

  // Text controllers
  final TextEditingController destinationController = TextEditingController();

  @override
  void onInit() async {
    super.onInit();
    mapController = MapController();
    
    // Ensure token is loaded before anything else
    final authController = Get.find<AuthController>();
    await authController.loadToken();
    log("🔑 Driver screen init with token: ${authController.token.value.isNotEmpty ? 'Token exists' : 'No token!'}");
    
    // Set default location first (for testing)
    _setDefaultLocation();
    
    // Only try to get actual location if explicitly requested
    // getUserLocation();
    checkLocationStatus();
    getDriverInfo();
    
    // Check for active rides when the screen loads
    checkForActiveRide();
  }

  Future<void> getDriverInfo() async {
    try {
      requestState.value = RequestState.loading;

      // Verify token availability
      final authController = Get.find<AuthController>();
      if (!authController.isValidToken()) {
        log("⚠️ Invalid token detected, redirecting to login");
        Get.snackbar(
          'Authentication Error', 
          'Please log in again',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        // Delay to allow snackbar to be seen
        await Future.delayed(const Duration(seconds: 2));
        Get.offAllNamed(AppRoutesNames.loginScreen);
        return;
      }
      
      // First, make a direct HTTP call to test the API
      await _testTokenWithDirectRequest(authController.token.value);
      
      // Try up to 3 times to get driver info
      Exception? lastError;
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          log("Fetching driver info - attempt ${attempt + 1}");

      // Fetch driver info from the API
          final Map<String, dynamic> driverInfo = await _driverService.getDriverProfile();
          log("Driver Info Response: $driverInfo"); 
          
          // Always set some values, even if empty
          driverEmail.value = driverInfo['email']?.toString() ?? 'No Email';
          driverProfilePic.value = driverInfo['profilePic']?.toString() ?? ''; 

      // Check if carDetails exists and is not null
      final carDetails = driverInfo['carDetails'];
          if (carDetails != null && carDetails is Map) {
            carMake.value = carDetails['make']?.toString() ?? 'Unknown';
            carModel.value = carDetails['model']?.toString() ?? 'Model';
            licensePlate.value = carDetails['licensePlate']?.toString() ?? 'No Plate';
      } else {
            log("⚠️ No car details found in response, using defaults");
            carMake.value = 'Unknown';
            carModel.value = 'Make';
            licensePlate.value = 'No Plate';
      }

          drivingLicense.value = driverInfo['drivingLicense']?.toString() ?? 'No License';

          log("📊 Loaded profile - Email: ${driverEmail.value}, Make: ${carMake.value}, Model: ${carModel.value}");

          // Success! Exit retry loop
      requestState.value = RequestState.online;
          return;
        } catch (e) {
          lastError = e as Exception;
          log("❌ Error fetching driver info (attempt ${attempt + 1}): $e");
          
          // If authentication error, break immediately
          if (e.toString().contains("Authentication failed") || 
              e.toString().contains("401")) {
            break;
          }
          
          // Otherwise wait before retry
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      
      // If we got here, all attempts failed
      requestState.value = RequestState.failed;
      
      // Check if it was an auth error
      if (lastError.toString().contains("Authentication failed") || 
          lastError.toString().contains("401")) {
        // Handle auth errors by redirecting to login
        Get.snackbar(
          'Authentication Error', 
          'Session expired. Please log in again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        await Future.delayed(const Duration(seconds: 2));
        await authController.clearToken();
        Get.offAllNamed(AppRoutesNames.loginScreen);
      } else {
        // Handle other errors with regular error message
        Get.snackbar(
          'Error', 
          'Failed to load driver info: ${lastError.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      log("❌ Unexpected error in getDriverInfo: $e");
      requestState.value = RequestState.failed;
      Get.snackbar(
        'Error', 
        'Unexpected error: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  Future<void> _testTokenWithDirectRequest(String token) async {
    try {
      final testUrl = "http://tariqi.zapto.org/api/driver/get/info";
      log("🧪 Testing token with direct HTTP request to: $testUrl");
      
      final response = await http.get(
        Uri.parse(testUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      log("🧪 Direct test - Status: ${response.statusCode}");
      log("🧪 Direct test - Body: ${response.body}");
      
      if (response.statusCode != 200) {
        log("⚠️ Direct API test failed with status ${response.statusCode}");
      } else {
        log("✅ Direct API test succeeded");
      }
    } catch (e) {
      log("❌ Direct API test exception: $e");
    }
  }

  // Add method to set default location
  void _setDefaultLocation() {
    log("📍 Setting default location for testing: ${defaultLocation.latitude}, ${defaultLocation.longitude}");
    
    // Set user position to the default location
    userPosition = defaultLocation;
    usingDefaultLocation.value = true;
    
    // Clear existing markers (if any) and add the current location marker
    markers.clear();
    markers.add(Marker(
      point: userPosition!,
      width: 40,
      height: 40,
      child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
    ));
    
    // Center the map on the user's position
    mapController.move(userPosition!, 15.0);
    
    requestState.value = RequestState.online;
    update();
    
    // Check if we're ready to start (if destination is set)
    checkReadyStatus();
  }

  Future<void> getUserLocation() async {
    try {
      requestState.value = RequestState.loading;
      
      // Get location using determinePosition helper method
      final position = await determinePosition();
      
      // Set user position from the retrieved location
      userPosition = LatLng(position.latitude, position.longitude);
      usingDefaultLocation.value = false;
      
      // Clear existing markers (if any) and add the current location marker
      markers.clear();
      markers.add(Marker(
        point: userPosition!,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
      ));
      
      // Center the map on the user's position
      if (mapController.camera.zoom < 14) {
        mapController.move(userPosition!, 15.0);
      } else {
        mapController.move(userPosition!, mapController.camera.zoom);
      }
      
      log("📍 Got real user location: ${userPosition?.latitude}, ${userPosition?.longitude}");
      
      requestState.value = RequestState.online;
      update();
      
      // Check if we're ready to start ride (if destination is also set)
      checkReadyStatus();
    } catch (e) {
      log("❌ Error getting user location: $e");
      requestState.value = RequestState.failed;
      isLocationDisabled.value = true;
      Get.snackbar(
        'Error', 
        'Failed to get location: $e', 
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<Position> determinePosition() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      isLocationDisabled.value = true;
      throw Exception('Location services are disabled. Please enable GPS in settings.');
    }

    // Check for location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Request permission if denied
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        isLocationDisabled.value = true;
        throw Exception('Location permissions are denied. Please enable in settings.');
      }
    }

    // Handle permanently denied permissions
    if (permission == LocationPermission.deniedForever) {
      isLocationDisabled.value = true;
      throw Exception('Location permissions are permanently denied. Please enable in app settings.');
    }

    // Permission granted, location services enabled
    isLocationDisabled.value = false;
    
    // Get current position with high accuracy
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
    );
  }

  void checkLocationStatus() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      
      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      
      // Set flag based on conditions
      isLocationDisabled.value = !serviceEnabled || 
                                permission == LocationPermission.denied || 
                                permission == LocationPermission.deniedForever;
                                
      if (!isLocationDisabled.value) {
        // If location is enabled and we have permission, fetch location
        getUserLocation();
      }
    } catch (e) {
      log("❌ Error checking location status: $e");
      isLocationDisabled.value = true;
    }
  }

  void setMaxPassengers(int value) {
    maxPassengers.value = value;
    checkReadyStatus();
  }

  Future<void> getDestinationLocation({required String location}) async {
    try {
      requestState.value = RequestState.loading;

      // 1. Geocode the destination address to get coordinates
      final geocodeResponse = await http.get(Uri.parse(
        'https://api.opencagedata.com/geocode/v1/json?q=${Uri.encodeComponent(location)}&key=${ApiLinksKeys.geoCodingKey}',
      ));

      if (geocodeResponse.statusCode != 200) {
        throw Exception('Failed to geocode destination');
      }

      final geocodeData = jsonDecode(geocodeResponse.body);
      if (geocodeData['results'].isEmpty) {
        throw Exception('No results found for destination');
      }

      final destLat = geocodeData['results'][0]['geometry']['lat'];
      final destLng = geocodeData['results'][0]['geometry']['lng'];
      final destination = LatLng(destLat, destLng);
      endLat = destLat;
      endLong = destLng;

      // 2. Add destination marker
      if (markers.length > 1) {
        markers.removeAt(1);
      }
      markers.add(Marker(
        point: destination,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_pin, color: Colors.blue, size: 40),
      ));

      // 3. Get route polyline from OpenRouteService
      if (userPosition != null) {
        final routeResponse = await http.post(
          Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car/geojson'),
          headers: {
            'Authorization': Secrets.openRouteServiceKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            "coordinates": [
              [userPosition!.longitude, userPosition!.latitude],
              [destLng, destLat]
            ]
          }),
        );

        if (routeResponse.statusCode != 200) {
          throw Exception('Failed to get route');
        }

        final routeData = jsonDecode(routeResponse.body);
        final coords = routeData['features'][0]['geometry']['coordinates'] as List;
        final polylinePoints = coords
            .map<LatLng>((c) => LatLng(c[1] as double, c[0] as double))
            .toList();

        routePolyline.clear();
        routePolyline.add(Polyline(
          points: polylinePoints,
          color: Colors.blue,
          strokeWidth: 4,
        ));
      }

      // 4. Update destination text field
      destinationController.text = await getLocationName(lat: destLat, long: destLng);

      requestState.value = RequestState.online;
      checkReadyStatus();
      update();
    } catch (e) {
      requestState.value = RequestState.failed;
      Get.snackbar('Error', 'Failed to find destination: $e');
    }
  }


  void setDestinationFromMap(LatLng latlng) async{
    // Remove previous destination marker if it exists (assume first marker is user, second is destination)
    if (markers.length > 1) {
      markers.removeAt(1);
    }
    // Add new destination marker
    markers.add(
      Marker(
        point: latlng,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_pin, color: Colors.blue, size: 40),
      ),
    );
    // Update destination text field
    destinationController.text = await getLocationName(lat: latlng.latitude, long: latlng.longitude);
    endLat = latlng.latitude;
    endLong = latlng.longitude;
    // Update route polyline
    routePolyline.clear();
    if (userPosition != null) {
      try {
        final routeResponse = await http.post(
          Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car/geojson'),
          headers: {
            'Authorization': Secrets.openRouteServiceKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            "coordinates": [
              [userPosition!.longitude, userPosition!.latitude],
              [latlng.longitude, latlng.latitude]
            ]
          }),
        );

        log("🛣️ Route API response status: ${routeResponse.statusCode}");

        if (routeResponse.statusCode == 200) {
        final routeData = jsonDecode(routeResponse.body);
          
          if (routeData.containsKey('features') && 
              routeData['features'] is List && 
              routeData['features'].isNotEmpty &&
              routeData['features'][0].containsKey('geometry') &&
              routeData['features'][0]['geometry'].containsKey('coordinates')) {
              
        final coords = routeData['features'][0]['geometry']['coordinates'] as List;
        final polylinePoints = coords
            .map<LatLng>((c) => LatLng(c[1] as double, c[0] as double))
            .toList();

        routePolyline.clear();
        routePolyline.add(Polyline(
          points: polylinePoints,
          color: Colors.blue,
          strokeWidth: 4,
        ));
          } else {
            log("⚠️ Invalid route data format: $routeData");
            // Use straight line as fallback
            _createStraightLineRoute(userPosition!, latlng);
          }
        } else {
          log("❌ Failed to get route: ${routeResponse.statusCode} - ${routeResponse.body}");
          // Use straight line as fallback
          _createStraightLineRoute(userPosition!, latlng);
        }
      } catch (e) {
        log("❌ Route calculation error: $e");
        // Use straight line as fallback - don't crash the app
        _createStraightLineRoute(userPosition!, latlng);
      }
      }
    checkReadyStatus();
    update(); // Notify GetBuilder to rebuild
  }
  
  void _createStraightLineRoute(LatLng start, LatLng end) {
    // Create a simple straight line as fallback when route service fails
    routePolyline.clear();
    routePolyline.add(Polyline(
      points: [start, end],
      color: Colors.red, // Red to indicate it's a fallback
      strokeWidth: 3,
    ));
    log("🔄 Created fallback straight line route");
  }

  Future<String> getLocationName({
    required double lat,
    required double long,
  }) async {
    final geoCodeKey = ApiLinksKeys.geoCodingKey;
    final url = Uri.parse(
      'https://api.opencagedata.com/geocode/v1/json?q=$lat+$long&key=$geoCodeKey&pretty=1',
    );
    try {
      requestState.value = RequestState.loading;
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'];
        if (results.isNotEmpty) {
          final locationName = results[0]['formatted'];

          requestState.value = RequestState.success;

          return locationName;
        } else {
          requestState.value = RequestState.failed;
        }
      } else {
        requestState.value = RequestState.failed;
      }
    } on TimeoutException catch (e) {
      requestState.value = RequestState.error;
      throw Exception('Request timeout: $e');
    } on SocketException catch (e) {
      requestState.value = RequestState.error;
      throw Exception('Network error: $e');
    } on HandshakeException catch (e) {
      requestState.value = RequestState.error;
      throw Exception('Handshake error: $e');
    } on Exception catch (e) {
      requestState.value = RequestState.error;
      throw Exception('Failed to get location: $e');
    }
    throw Exception('Failed to get location name');
  }

  void checkReadyStatus() {
    isReadyToStart.value = destinationController.text.isNotEmpty && 
        userPosition != null && 
        markers.length >= 2;
  }

  Future<void> startRide() async {
    // First check if driver already has an active ride
    await checkForActiveRide();
    
    if (hasActiveRide.value) {
      // Show dialog instead of snackbar
      Get.dialog(
        AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.directions_car, color: Colors.blue),
              const SizedBox(width: 10),
              const Text("Active Ride Exists", 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            "You already have an active ride. Would you like to resume it?",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(), // Close the dialog
              child: const Text("CANCEL"),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Get.back(); // Close the dialog
                goToActiveRide();
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text("RESUME RIDE"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        barrierDismissible: false,
      );
      return;
    }
    
    if (!isReadyToStart.value) {
      Get.snackbar(
        'Error',
        'Please set a destination and ensure your location is available',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      // First dismiss any existing snackbars and dialogs
      if (Get.isSnackbarOpen) Get.closeAllSnackbars();
      if (Get.isDialogOpen!) Get.back();
      
      // Show loading dialog
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        barrierDismissible: false,
      );
      
      // Set loading state
      requestState.value = RequestState.loading;
      
      // Check user location
      if (userPosition == null) {
        throw Exception('User location not available');
      }

      // Verify coordinates are valid
      if (userPosition!.latitude == 0 || userPosition!.longitude == 0 ||
          endLat == 0 || endLong == 0) {
        throw Exception('Invalid coordinates detected. Please select a valid destination.');
      }

      log("🚀 ---------- RIDE CREATION ATTEMPT ----------");
      log("🚀 Using location mode: ${usingDefaultLocation.value ? 'DEFAULT LOCATION' : 'REAL LOCATION'}");
      log("🚀 Starting coordinates: ${userPosition!.latitude}, ${userPosition!.longitude}");
      log("🚀 Destination coordinates: $endLat, $endLong");
      log("🚀 Destination address: ${destinationController.text}");
      log("🚀 Max Passengers: ${maxPassengers.value}");
      
      // Attempt to create the ride
      final result = await _driverService.startRide(
        startLocation: userPosition!,
        destination: destinationController.text,
        maxPassengers: maxPassengers.value,
      );
      
      log("✅ RIDE CREATION RESPONSE: $result");
      
      // Extract ride ID and verify it
      String? rideId;
      if (result.containsKey('ride') && result['ride'] is Map) {
        final rideData = result['ride'] as Map<String, dynamic>;
        rideId = rideData['_id']?.toString();
        log("✅ Ride created with ID: $rideId");
        
        // Log all fields in the ride object for debugging
        log("📋 FULL RIDE OBJECT:");
        rideData.forEach((key, value) {
          log("    $key: $value");
        });
      } else {
        log("⚠️ 'ride' field missing or not a Map: ${result['ride']}");
      }
      
      if (rideId == null || rideId.isEmpty) {
        log("⚠️ No valid ride ID found in response");
        rideId = _driverService.currentRideId; // Fallback to stored ID
        log("🔄 Using fallback ride ID: $rideId");
      }
      
      // Ensure the current ride ID is set in the service
      if (rideId != null && rideId.isNotEmpty) {
        _driverService.currentRideId = rideId;
        // Update our local tracking
        hasActiveRide.value = true;
        activeRideId.value = rideId;
      }
      
      // Set success state
      requestState.value = RequestState.success;
      
      // Close any loading dialog
      if (Get.isDialogOpen!) Get.back();
      
      // DIRECT NAVIGATION WITHOUT SHOWING SNACKBAR
      log("🚕 Directly navigating to active ride screen with rideId: $rideId without snackbar");
      await Get.off(
        () => DriverActiveRideScreen(),
        arguments: {'rideId': rideId},
        transition: Transition.rightToLeft,
        duration: const Duration(milliseconds: 300),
      );
      
    } catch (e) {
      // Clean up any dialogs first
      if (Get.isDialogOpen!) Get.back();
      
      requestState.value = RequestState.failed;
      log("❌ RIDE CREATION ERROR: $e");
      
      // Extract error message for display
      String errorMessage = 'Failed to start ride';
      if (e.toString().contains("message")) {
        try {
          final errorString = e.toString();
          final messageStart = errorString.indexOf("message") + 10;
          final messageEnd = errorString.indexOf("\"", messageStart);
          if (messageStart > 10 && messageEnd > messageStart) {
            errorMessage = errorString.substring(messageStart, messageEnd);
          }
        } catch (_) {
          errorMessage = e.toString();
        }
      }
      
      // Close all snackbars before showing an error
      Get.closeAllSnackbars();
      
      // Handle "already in a ride" error specially
      if (errorMessage.toLowerCase().contains("already in a ride")) {
        // First check if we have an active ride ID
        checkForActiveRide().then((_) {
          // Show a custom dialog instead of a snackbar
          Get.dialog(
            AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.directions_car, color: Colors.blue),
                  const SizedBox(width: 10),
                  const Text("Already in a Ride", 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: const Text(
                "You already have an active ride. Would you like to go to your existing ride?",
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Get.back(), // Close the dialog
                  child: const Text("CANCEL"),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Get.back(); // Close the dialog
                    // Navigate to active ride screen
                    if (hasActiveRide.value && activeRideId.value.isNotEmpty) {
                      navigateToActiveRide(activeRideId.value);
                    } else {
                      // Try one more time to get the ride ID
                      _driverService.hasActiveRide().then((hasRide) {
                        if (hasRide && _driverService.currentRideId != null) {
                          navigateToActiveRide(_driverService.currentRideId);
                        } else {
                          Get.snackbar(
                            'Error',
                            'Could not find your active ride',
                            backgroundColor: Colors.red,
                            colorText: Colors.white
                          );
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text("GO TO RIDE"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            barrierDismissible: false,
          );
        });
      } else {
        // Show regular error snackbar for other errors
        Get.snackbar(
          'Error',
          errorMessage,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      }
    }
  }
  
  // Optional: Keep this as a separate method for reuse elsewhere
  void navigateToActiveRide(String? rideId) {
    try {
      // Check if ride ID is valid
      if (rideId == null || rideId.isEmpty) {
        log("⚠️ Invalid ride ID for navigation: $rideId");
        
        // Show a helpful error message
        Get.snackbar(
          'Navigation Error',
          'Could not find your active ride. Please try starting a new ride.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
        return;
      }
      
      log("🚕 Navigating to active ride screen with rideId: $rideId");
      
      // Close any dialogs or snackbars
      if (Get.isDialogOpen!) Get.back();
      Get.closeAllSnackbars();
      
      // Save the ride ID to the service for good measure
      _driverService.currentRideId = rideId;
      
      // Use off instead of to for proper navigation
      Get.off(
        () => DriverActiveRideScreen(),
        arguments: {'rideId': rideId},
        transition: Transition.rightToLeft,
        duration: const Duration(milliseconds: 300),
      );
    } catch (e) {
      // Log error and show user feedback
      log("❌ Error navigating to active ride: $e");
      
      Get.snackbar(
        'Navigation Error',
        'Could not navigate to your active ride: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }

  void logout() async {
    try {
      // End all active rides first
      await _driverService.endAllActiveRides();
      
      // Clear auth token and redirect to login
      final authController = Get.find<AuthController>();
      await authController.clearToken();
      
      Get.offAllNamed(AppRoutesNames.loginScreen);
    } catch (e) {
      log("❌ Error during logout: $e");
      // Even if there's an error, still try to log out
      Get.offAllNamed(AppRoutesNames.loginScreen);
    }
  }

  // Check if driver has an active ride
  Future<void> checkForActiveRide() async {
    try {
      log("🔍 Checking for active rides...");
      final bool hasRide = await _driverService.hasActiveRide();
      
      if (hasRide && _driverService.currentRideId != null) {
        hasActiveRide.value = true;
        activeRideId.value = _driverService.currentRideId!;
        log("✅ Found active ride with ID: ${activeRideId.value}");
      } else {
        hasActiveRide.value = false;
        activeRideId.value = '';
        log("ℹ️ No active ride found");
      }
    } catch (e) {
      log("❌ Error checking for active ride: $e");
      hasActiveRide.value = false;
      activeRideId.value = '';
    }
  }
  
  // Navigate to active ride screen
  void goToActiveRide() {
    if (hasActiveRide.value && activeRideId.value.isNotEmpty) {
      log("🚕 Going to active ride with ID: ${activeRideId.value}");
      // Use the navigateToActiveRide method for consistency
      navigateToActiveRide(activeRideId.value);
    } else {
      // First try to refresh active ride status
      checkForActiveRide().then((_) {
        if (hasActiveRide.value && activeRideId.value.isNotEmpty) {
          // Try again after refresh
          navigateToActiveRide(activeRideId.value);
        } else {
          // Show error if still no active ride found
          Get.snackbar(
            'No Active Ride',
            'You don\'t have an active ride at the moment',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
        }
      });
    }
  }
}


double endLat = 0.0;
double endLong = 0.0;