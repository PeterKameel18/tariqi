// lib/controller/driver/driver_active_ride_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/services/driver_service.dart';
import 'package:tariqi/const/api_endpoints.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'package:tariqi/controller/auth_controllers/auth_controller.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:tariqi/models/chat_message.dart';
import 'package:tariqi/const/secrets.dart';

// Global variable to hold route data
RxList<dynamic> routes = <dynamic>[].obs;

class DriverActiveRideController extends GetxController {
  // Initialize with a safeguard mechanism
  late final DriverService _driverService;
  final Rx<RequestState> requestState = RequestState.loading.obs;
  final RxList<Map<String, dynamic>> passengers = <Map<String, dynamic>>[].obs;
  final RxBool hasPendingRequest = false.obs;
  final RxMap<String, dynamic> pendingRequest = <String, dynamic>{}.obs;

  // Location permission status
  final RxBool locationPermissionGranted = false.obs;

  // Sound player
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Ride info
  late String destination = "";
  late int etaMinutes = 0;
  late double distanceKm = 0.0;
  late LatLng currentLocation = LatLng(0.0, 0.0);
  late LatLng destinationLocation = LatLng(0.0, 0.0);
  String? rideId;

  // Map controllers
  late MapController mapController;
  final List<Marker> markers = [];
  final List<Polyline> routePolyline = [];

  // Periodic timers for updates
  Timer? _locationUpdateTimer;
  Timer? _rideStatusTimer;
  Timer? _pendingRequestsTimer;
  Timer? _destinationCheckTimer;

  final String openRouteServiceApiKey = Secrets.openRouteServiceKey;

  // Passenger pickup location
  LatLng? passengerPickupLocation;

  @override
  void onInit() {
    super.onInit();

    // Initialize with default values first to prevent null errors
    currentLocation = LatLng(24.7136, 46.6753); // Default to Riyadh
    destinationLocation = LatLng(24.7236, 46.6953);

    // Initialize map controller
    mapController = MapController();

    // Add default markers
    markers.clear();
    markers.addAll([
      Marker(
        point: currentLocation,
        width: 100,
        height: 100,
        child: Image.asset('assets/images/car.png', width: 100, height: 100),
      ),
      Marker(
        point: destinationLocation,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_pin, color: Colors.blue, size: 40),
      ),
    ]);

    // Add default route
    routePolyline.clear();
    routePolyline.add(
      Polyline(
        points: [currentLocation, destinationLocation],
        color: Colors.blue,
        strokeWidth: 4,
      ),
    );

    // Set loading state
    requestState.value = RequestState.loading;

    // Try to find DriverService or create it if not found
    try {
      _driverService = Get.find<DriverService>();
      dev.log("✅ Found existing DriverService instance");
    } catch (e) {
      dev.log("⚠️ DriverService not found, creating new instance");
      _driverService = Get.put(DriverService());
    }

    // Check location permissions first
    _checkLocationPermission();

    // Get the current ride ID from the DriverService
    rideId = _driverService.currentRideId;
    dev.log("🚗 Active Ride Controller - Current ride ID: $rideId");

    // Try to load saved passenger data for this ride if available
    _loadSavedPassengerData();

    // Initial data loading will be triggered after location permission check
  }

  // Add this method to check location permission
  Future<void> _checkLocationPermission() async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        dev.log("📍 Location services are disabled");
        locationPermissionGranted.value = false;

        // Even without location, we should still try to load ride data
        loadRideData();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        dev.log("📍 Location permission is denied, requesting permission...");
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        dev.log("📍 Location permission is denied");
        locationPermissionGranted.value = false;

        // Even without location, we should still try to load ride data
        loadRideData();
        return;
      }

      // Permission granted, start location services
      locationPermissionGranted.value = true;
      dev.log("📍 Location permission granted, starting services");

      // Set up periodic updates once permission is granted
      _startPeriodicUpdates();

      // Load ride data
      loadRideData();
    } catch (e) {
      dev.log("❌ Error checking location permission: $e");
      locationPermissionGranted.value = false;

      // Even on error, still try to load ride data
      loadRideData();
    }
  }

  // Method to request location permission
  Future<void> requestLocationPermission() async {
    try {
      // First check if location services are enabled on the device
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled
        _showLocationServiceDisabledError();
        return;
      }

      LocationPermission permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        dev.log("📍 Location permission request was denied");
        locationPermissionGranted.value = false;
        _showLocationPermissionError();
        return;
      }

      // Permission granted, start location services
      locationPermissionGranted.value = true;
      dev.log("📍 Location permission was granted");

      // Start periodic updates
      _startPeriodicUpdates();

      // Reload ride data
      loadRideData();

      // Remove any error messages
      if (Get.isSnackbarOpen) {
        Get.closeCurrentSnackbar();
      }
    } catch (e) {
      dev.log("❌ Error requesting location permission: $e");

      // Special handling for Windows
      if (e.toString().contains("Location settings are not satisfied") ||
          e.toString().contains("location permission")) {
        _showWindowsLocationInstructions();
      } else {
        _showLocationPermissionError();
      }
    }
  }

  // Show Windows-specific location instructions
  void _showWindowsLocationInstructions() {
    Get.dialog(
      AlertDialog(
        title: Text('Windows Location Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To enable location on Windows:'),
            SizedBox(height: 8),
            Text('1. Open Windows Settings'),
            Text('2. Go to Privacy & Security'),
            Text('3. Select Location'),
            Text('4. Turn on "Location service"'),
            Text('5. Under App permissions, enable location access for apps'),
            SizedBox(height: 16),
            Text('After enabling location, restart the application.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Close')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              useFallbackLocation();
            },
            child: Text('Use Default Location'),
          ),
        ],
      ),
    );
  }

  // Show location services disabled error
  void _showLocationServiceDisabledError() {
    Get.dialog(
      AlertDialog(
        title: Text('Location Services Disabled'),
        content: Text(
          'Location services are disabled on your device. Please enable location services in your system settings.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Close')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              useFallbackLocation();
            },
            child: Text('Use Default Location'),
          ),
        ],
      ),
    );
  }

  // Use fallback location when permissions are not available
  void useFallbackLocation() {
    dev.log("📍 Using fallback location data for Windows");

    // Set a default location (can be configured for your specific app needs)
    currentLocation = LatLng(24.7136, 46.6753); // Default to Riyadh

    // Use fallback location but still start the ride
    locationPermissionGranted.value = true;

    // Create a simulated route and start ride
    _createFallbackRoute();

    // Start periodic updates, but they'll use fallback data
    _startPeriodicUpdates();

    // Update UI
    update();
  }

  // Show location permission error message
  void _showLocationPermissionError() {
    Get.snackbar(
      'Error',
      'Failed to get location: Exception: Location permissions are denied. Please enable in settings.',
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: Duration(seconds: 5),
      mainButton: TextButton(
        onPressed: () => requestLocationPermission(),
        child: Text(
          'Enable',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  void onClose() {
    // Save passenger data before closing controller
    _savePassengersToService();
    
    _audioPlayer.dispose();
    // Cancel all timers when controller is closed
    _locationUpdateTimer?.cancel();
    _rideStatusTimer?.cancel();
    _pendingRequestsTimer?.cancel();
    _destinationCheckTimer?.cancel();
    super.onClose();
  }

  void _startPeriodicUpdates() {
    // Cancel any existing timers first
    _locationUpdateTimer?.cancel();
    _rideStatusTimer?.cancel();
    _pendingRequestsTimer?.cancel();
    _destinationCheckTimer?.cancel();

    // Update driver location every 10 seconds
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => updateDriverLocation(),
    );

    // Fetch ride status every 15 seconds
    _rideStatusTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => refreshRideStatus(),
    );

    // Check for pending requests every 20 seconds
    _pendingRequestsTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => fetchPendingRequests(),
    );
    
    // Check for non-picked up passengers and reroute to destination if none found
    _destinationCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => checkAndRouteToDestination(),
    );
  }

  Future<void> loadRideData() async {
    if (rideId == null || rideId!.isEmpty) {
      dev.log("❌ Cannot load ride data: No ride ID available");

      // Check if we can get an active ride ID from the service
      final driverService = Get.find<DriverService>();
      final hasActiveRide = await driverService.hasActiveRide();

      if (hasActiveRide && driverService.currentRideId != null) {
        rideId = driverService.currentRideId;
        dev.log("✅ Found active ride ID from service: $rideId");
      } else {
        requestState.value = RequestState.failed;
        Get.snackbar(
          "No Ride Found",
          "Could not find an active ride to display",
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
        return;
      }
    }

    try {
      requestState.value = RequestState.loading;
      dev.log("🔄 Loading ride data for ride ID: $rideId");

      // Check if we have saved passenger data first
      if (passengers.isEmpty) {
        // If we have no passenger data in memory, try to load from service
        final savedPassengers = await _driverService.getSavedPassengers(rideId!);
        if (savedPassengers != null && savedPassengers.isNotEmpty) {
          dev.log("✅ Loaded ${savedPassengers.length} saved passengers from service");
          passengers.clear();
          passengers.addAll(savedPassengers);
        }
      }

      // First try to get ride data via the DriverService
      final rideData = await _driverService.getRideData(rideId!);

      if (rideData != null) {
        dev.log("✅ Successfully loaded ride data");

        // Process route data
        if (rideData.containsKey('route') && rideData['route'] is List) {
          routes.clear();
          routes.addAll(rideData['route']);
          dev.log("✅ Successfully extracted route data");
          initializeRideFromRoute();
        } else {
          dev.log("⚠️ No route data in response, using fallback");
          await _createFallbackRoute();
        }

        // Load passengers from API only if we don't have saved passengers
        if (passengers.isEmpty && rideData.containsKey('passengers') &&
            rideData['passengers'] is List) {
          dev.log("🔄 Loading passengers from API response");
          passengers.clear();
          for (var passenger in rideData['passengers']) {
            passengers.add({
              'id': passenger['_id'] ?? '',
              'name': passenger['name'] ?? 'Passenger',
              'rating': passenger['rating'] ?? 5.0,
              'profilePic':
                  passenger['profilePic'] ?? 'https://via.placeholder.com/150',
              'price': passenger['price'],
              'pickedUp': passenger['pickedUp'] ?? false,
              'droppedOff': passenger['droppedOff'] ?? false,
              'pickup': passenger['pickup'] ?? 'Current location',
              'dropoff': passenger['dropoff'] ?? 'Destination',
              'pickupLocation': passenger['pickupLocation'] != null 
                  ? LatLng(passenger['pickupLocation']['lat'], passenger['pickupLocation']['lng']) 
                  : null,
              'dropoffLocation': passenger['dropoffLocation'] != null 
                  ? LatLng(passenger['dropoffLocation']['lat'], passenger['dropoffLocation']['lng']) 
                  : null,
            });
          }
          dev.log("✅ Successfully loaded ${passengers.length} passengers from API");
          
          // Save the passengers to the service for persistence
          _savePassengersToService();
        }

        requestState.value = RequestState.online;
        return;
      }

      // If DriverService approach failed, try a direct API call
      dev.log(
        "⚠️ Failed to get ride data from service, trying direct API call",
      );

      final token = Get.find<AuthController>().token.value;
      if (token.isEmpty) {
        throw Exception("No auth token available");
      }

      // Use the correct endpoint based on the API design
      final endpoint = "${ApiEndpoints.baseUrl}/user/get/ride/data/$rideId";
      dev.log("🔍 Trying API endpoint: $endpoint");

      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      dev.log("📊 API response: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Extract ride data
        final Map<String, dynamic> directRideData;
        if (data.containsKey('ride')) {
          directRideData = data['ride'];
          dev.log("✅ Found ride data in 'ride' field");
        } else {
          directRideData = data;
          dev.log("✅ Using full response as ride data");
        }

        // Process route data
        if (directRideData.containsKey('route') &&
            directRideData['route'] is List) {
          routes.clear();
          routes.addAll(directRideData['route']);
          dev.log("✅ Successfully extracted route data");
          initializeRideFromRoute();
        } else {
          dev.log("⚠️ No route data in response, using fallback");
          await _createFallbackRoute();
        }

        // Load passengers
        if (directRideData.containsKey('passengers') &&
            directRideData['passengers'] is List) {
          passengers.clear();
          for (var passenger in directRideData['passengers']) {
            passengers.add({
              'id': passenger['_id'] ?? '',
              'name': passenger['name'] ?? 'Passenger',
              'rating': passenger['rating'] ?? 5.0,
              'profilePic':
                  passenger['profilePic'] ?? 'https://via.placeholder.com/150',
              'price': passenger['price'],
              'pickedUp': passenger['pickedUp'] ?? false,
              'droppedOff': passenger['droppedOff'] ?? false,
              'pickup': passenger['pickup'] ?? 'Current location',
              'dropoff': passenger['dropoff'] ?? 'Destination',
              'pickupLocation': passenger['pickupLocation'] != null 
                  ? LatLng(passenger['pickupLocation']['lat'], passenger['pickupLocation']['lng']) 
                  : null,
              'dropoffLocation': passenger['dropoffLocation'] != null 
                  ? LatLng(passenger['dropoffLocation']['lat'], passenger['dropoffLocation']['lng']) 
                  : null,
            });
          }
          dev.log("✅ Successfully loaded ${passengers.length} passengers from API");
          
          // Save the passengers to the service for persistence
          _savePassengersToService();
        }

        requestState.value = RequestState.online;
        return;
      }

      // If we got here, all attempts failed
      dev.log("❌ Failed to load ride data");
      requestState.value = RequestState.failed;

      // Show error with retry button
      Get.snackbar(
        "Connection Error",
        "Could not load the ride data. Please try again.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 10),
        mainButton: TextButton(
          onPressed: () {
            loadRideData(); // Retry loading ride data
          },
          child: Text(
            "Retry",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );

      // Try to recover with fallback data
      await _createFallbackRoute();
    } catch (e) {
      dev.log("❌ Error loading ride data: $e");
      requestState.value = RequestState.failed;

      // Show error with retry button
      Get.snackbar(
        "Connection Error",
        "Could not connect to the server. Tap retry to try again.",
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: Duration(seconds: 10),
        mainButton: TextButton(
          onPressed: () {
            loadRideData(); // Retry loading ride data
          },
          child: Text(
            "Retry",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );

      // Try to recover with fallback data
      await _createFallbackRoute();
    }
  }

  Future<void> _createFallbackRoute() async {
    dev.log("🔄 Creating fallback route data");

    try {
      // Try to get current location
      Position position;
      try {
        position = await Geolocator.getCurrentPosition();
        currentLocation = LatLng(position.latitude, position.longitude);
        dev.log("✅ Using current location for fallback: $currentLocation");
      } catch (e) {
        dev.log("⚠️ Could not get current location, using defaults for Riyadh");
        // Default to Riyadh, Saudi Arabia
        currentLocation = LatLng(24.7136, 46.6753);
      }

      // Create a destination point slightly northeast of current location
      destinationLocation = LatLng(
        currentLocation.latitude + 0.01,
        currentLocation.longitude + 0.01,
      );

      // Validate coordinates are within allowed bounds
      if (currentLocation.latitude < -90 ||
          currentLocation.latitude > 90 ||
          currentLocation.longitude < -180 ||
          currentLocation.longitude > 180) {
        dev.log("⚠️ Invalid current location coordinates, using defaults");
        currentLocation = LatLng(24.7136, 46.6753);
      }

      if (destinationLocation.latitude < -90 ||
          destinationLocation.latitude > 90 ||
          destinationLocation.longitude < -180 ||
          destinationLocation.longitude > 180) {
        dev.log("⚠️ Invalid destination coordinates, using defaults");
        destinationLocation = LatLng(24.7236, 46.6953);
      }
    } catch (e) {
      dev.log("⚠️ Error in fallback route creation: $e, using defaults");
      currentLocation = LatLng(24.7136, 46.6753);
      destinationLocation = LatLng(24.7236, 46.6953);
    }

    // Set up route data
    routes.clear();
    routes.addAll([
      {"lat": currentLocation.latitude, "lng": currentLocation.longitude},
      {
        "lat": destinationLocation.latitude,
        "lng": destinationLocation.longitude,
      },
    ]);

    // Set default ride information
    distanceKm = 2.5; // Approximately 2.5 km
    etaMinutes = 10; // 10 minutes ETA
    destination = "Default Destination";

    // Create markers
    markers.clear();
    markers.addAll([
      Marker(
        point: currentLocation,
        width: 40,
        height: 40,
        child: Image.asset('assets/images/car.png', width: 40, height: 40),
      ),
      Marker(
        point: destinationLocation,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_pin, color: Colors.blue, size: 40),
      ),
    ]);

    // Create route polyline
    routePolyline.clear();
    routePolyline.add(
      Polyline(
        points: [currentLocation, destinationLocation],
        color: Colors.blue,
        strokeWidth: 4,
      ),
    );

    dev.log("✅ Created fallback route data successfully");

    // Update UI
    update();

    // Initialize from this route
    initializeRideFromRoute();
  }

  void initializeRideFromRoute() {
    try {
      dev.log("🔄 Initializing ride from routes: $routes");

      // Skip if already initialized
      if (requestState.value == RequestState.online &&
          markers.isNotEmpty &&
          routePolyline.isNotEmpty) {
        dev.log(
          "✅ Ride already initialized, skipping redundant initialization",
        );
        return;
      }

      // Parse stored global routes with validation
      final validPoints = <LatLng>[];

      for (var pt in routes) {
        try {
          final m =
              pt is Map<String, dynamic>
                  ? pt
                  : Map<String, dynamic>.from(pt as Map);
          final double lat = m['lat'] as double;
          final double lng = m['lng'] as double;

          // Validate coordinates are within allowed bounds
          if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
            validPoints.add(LatLng(lat, lng));
          } else {
            dev.log("⚠️ Skipping invalid route point: lat=$lat, lng=$lng");
          }
        } catch (e) {
          dev.log("⚠️ Error processing route point: $e");
        }
      }

      if (validPoints.length < 2) {
        dev.log("⚠️ Not enough valid points in route data, using defaults");
        currentLocation = LatLng(24.7136, 46.6753);
        destinationLocation = LatLng(24.7236, 46.6953);
      } else {
        // Assign start & destination
        currentLocation = validPoints.first;
        destinationLocation = validPoints.last;
      }

      // Add map markers
      markers.clear();
      markers.addAll([
        Marker(
          point: currentLocation,
          width: 40,
          height: 40,
          child: Image.asset('assets/images/car.png', width: 40, height: 40),
        ),
        Marker(
          point: destinationLocation,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_pin, color: Colors.blue, size: 40),
        ),
      ]);

      // Get destination name and route info immediately
      _getRouteInfoFromOpenRouteService();

      update(); // Update UI
    } catch (e) {
      dev.log("❌ Error initializing ride: $e");
      _handleInitializationError();
    }
  }

  // Get route information from OpenRouteService API
  Future<void> _getRouteInfoFromOpenRouteService() async {
    try {
      // Set default values first
      distanceKm = _computeDistanceKm(currentLocation, destinationLocation);
      etaMinutes =
          (distanceKm / 30.0 * 60).round(); // Assuming 30 km/h avg speed
      destination =
          '${destinationLocation.latitude.toStringAsFixed(4)}, ${destinationLocation.longitude.toStringAsFixed(4)}';

      // First get destination address from geocoding
      await _getDestinationName();

      // Then get more accurate route info
      final response = await http.post(
        Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car'),
        headers: {
          'Authorization': openRouteServiceApiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "coordinates": [
            [currentLocation.longitude, currentLocation.latitude],
            [destinationLocation.longitude, destinationLocation.latitude],
          ],
          "instructions": true,
          "format": "json",
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data.containsKey('routes') &&
            data['routes'] is List &&
            data['routes'].isNotEmpty) {
          final route = data['routes'][0];

          // Extract distance and duration
          if (route.containsKey('summary')) {
            final summary = route['summary'];
            if (summary.containsKey('distance')) {
              // Distance is in meters, convert to km
              distanceKm = (summary['distance'] / 1000).toDouble();
            }

            if (summary.containsKey('duration')) {
              // Duration is in seconds, convert to minutes
              etaMinutes = (summary['duration'] / 60).round();
            }
          }

          // Create polyline from route geometry
          if (route.containsKey('geometry')) {
            _createRoutePolylineFromGeometry(route['geometry']);
          }

          update(); // Update UI with new info
        }
      } else {
        dev.log(
          "⚠️ OpenRouteService API error: ${response.statusCode} - ${response.body}",
        );
        // Fallback to simple polyline
        _createRoutePolyline();
      }
    } catch (e) {
      dev.log("❌ Error getting route info: $e");
      // Fallback to simple route calculation
      _createRoutePolyline();
    }
  }

  // Get destination name using reverse geocoding
  Future<void> _getDestinationName() async {
    try {
      dev.log(
        "🔍 Getting destination name for: ${destinationLocation.latitude}, ${destinationLocation.longitude}",
      );

      // Try multiple geocoding services
      bool success = false;

      // First attempt: OpenCage geocoding service
      try {
        final response = await http.get(
          Uri.parse(
            'https://api.opencagedata.com/geocode/v1/json?q=${destinationLocation.latitude}+${destinationLocation.longitude}&key=8c0bbd95e01c4d74809e1c5756d446a5&pretty=1',
          ),
          headers: {'Accept': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          dev.log("🔍 OpenCage geocoding response: ${response.statusCode}");

          if (data.containsKey('results') &&
              data['results'] is List &&
              data['results'].isNotEmpty) {
            final result = data['results'][0];

            // Check if we have a formatted address
            if (result.containsKey('formatted')) {
              destination = result['formatted'];
              dev.log("✅ Found destination name: $destination");
              success = true;
            }
            // Otherwise try to build address from components
            else if (result.containsKey('components')) {
              final components = result['components'];
              final List<String> addressParts = [];

              if (components.containsKey('road')) {
                addressParts.add(components['road']);
              }
              if (components.containsKey('suburb')) {
                addressParts.add(components['suburb']);
              }
              if (components.containsKey('city')) {
                addressParts.add(components['city']);
              }
              if (components.containsKey('state')) {
                addressParts.add(components['state']);
              }

              if (addressParts.isNotEmpty) {
                destination = addressParts.join(', ');
                dev.log(
                  "✅ Built destination name from components: $destination",
                );
                success = true;
              }
            }
          }
        } else {
          dev.log("⚠️ OpenCage geocoding error: ${response.statusCode}");
        }
      } catch (e) {
        dev.log("⚠️ OpenCage error: $e");
      }

      // Second attempt: Try Nominatim (free, no key required)
      if (!success) {
        try {
          dev.log("🔍 Trying Nominatim geocoding fallback");
          final nominatimResponse = await http.get(
            Uri.parse(
              'https://nominatim.openstreetmap.org/reverse?format=json&lat=${destinationLocation.latitude}&lon=${destinationLocation.longitude}&zoom=18&addressdetails=1',
            ),
            headers: {'User-Agent': 'Tariqi-App/1.0'},
          );

          if (nominatimResponse.statusCode == 200) {
            final nominatimData = jsonDecode(nominatimResponse.body);
            if (nominatimData['display_name'] != null) {
              destination = nominatimData['display_name'];
              dev.log("✅ Found Nominatim destination name: $destination");
              success = true;
            }
          } else {
            dev.log(
              "⚠️ Nominatim geocoding error: ${nominatimResponse.statusCode}",
            );
          }
        } catch (e) {
          dev.log("⚠️ Nominatim error: $e");
        }
      }

      // If both services failed, use a custom destination name
      if (!success) {
        // Generate a more descriptive name based on coordinates
        final lat = destinationLocation.latitude.toStringAsFixed(4);
        final lng = destinationLocation.longitude.toStringAsFixed(4);
        destination = "Custom Destination ($lat, $lng)";
        dev.log("⚠️ Geocoding failed, using custom destination name");
      }

      update(); // Update UI with new destination name
    } catch (e) {
      dev.log("❌ Error getting destination name: $e");
      // Fallback to a nicer display than raw coordinates
      destination = "Custom Destination";
      update();
    }
  }

  // Create route polyline from OpenRouteService geometry
  void _createRoutePolylineFromGeometry(String encodedGeometry) {
    try {
      routePolyline.clear();

      // Decode the geometry string (polyline format)
      final List<LatLng> decodedPoints = _decodePolyline(encodedGeometry);

      if (decodedPoints.isNotEmpty) {
        routePolyline.add(
          Polyline(points: decodedPoints, color: Colors.blue, strokeWidth: 4),
        );

        update();
      } else {
        // Fallback to simple line if decoding fails
        _createRoutePolyline();
      }
    } catch (e) {
      dev.log("❌ Error creating polyline from geometry: $e");
      _createRoutePolyline();
    }
  }

  // Decode polyline from encoded string (polyline algorithm)
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    try {
      while (index < len) {
        int b, shift = 0, result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;

        shift = 0;
        result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        // Convert to double and validate bounds before adding
        double latitude = lat / 1E5;
        double longitude = lng / 1E5;

        // Ensure coordinates are within valid ranges
        if (latitude >= -90 &&
            latitude <= 90 &&
            longitude >= -180 &&
            longitude <= 180) {
          points.add(LatLng(latitude, longitude));
        } else {
          // Log the invalid point for debugging
          dev.log(
            "⚠️ Skipping invalid coordinates: lat=$latitude, lng=$longitude",
          );
        }
      }
    } catch (e) {
      dev.log("❌ Error decoding polyline: $e");
    }

    return points;
  }

  Future<void> _createRoutePolyline() async {
    try {
      routePolyline.clear();

      // Try to get a proper route from OpenRouteService
      final routeResponse = await http.post(
        Uri.parse(
          'https://api.openrouteservice.org/v2/directions/driving-car/geojson',
        ),
        headers: {
          'Authorization': openRouteServiceApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "coordinates": [
            [currentLocation.longitude, currentLocation.latitude],
            [destinationLocation.longitude, destinationLocation.latitude],
          ],
        }),
      );

      if (routeResponse.statusCode == 200) {
        final routeData = jsonDecode(routeResponse.body);
        if (routeData.containsKey('features') &&
            routeData['features'] is List &&
            routeData['features'].isNotEmpty) {
          final coords =
              routeData['features'][0]['geometry']['coordinates'] as List;
          final validCoords = <LatLng>[];

          // Process and validate each coordinate
          for (var c in coords) {
            try {
              final double lng = c[0] as double;
              final double lat = c[1] as double;

              // Ensure coordinates are within valid ranges
              if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
                validCoords.add(LatLng(lat, lng));
              } else {
                dev.log(
                  "⚠️ Skipping invalid coordinates in route: lat=$lat, lng=$lng",
                );
              }
            } catch (e) {
              dev.log("⚠️ Error processing coordinate: $e");
            }
          }

          if (validCoords.isNotEmpty) {
            routePolyline.add(
              Polyline(points: validCoords, color: Colors.blue, strokeWidth: 4),
            );
            return;
          } else {
            dev.log("⚠️ No valid route points found, using fallback");
          }
        }
      }

      // Fallback to straight line if route service fails
      dev.log("⚠️ Could not get route from service, using straight line");
      routePolyline.add(
        Polyline(
          points: [currentLocation, destinationLocation],
          color: Colors.blue,
          strokeWidth: 4,
        ),
      );
    } catch (e) {
      dev.log("❌ Error creating route polyline: $e");

      // Use simple straight line as ultimate fallback
      routePolyline.add(
        Polyline(
          points: [currentLocation, destinationLocation],
          color: Colors.red, // Red to indicate error
          strokeWidth: 4,
        ),
      );
    }
  }

  void _handleInitializationError() {
    // Set fallback values
    currentLocation = LatLng(24.7136, 46.6753);
    destinationLocation = LatLng(24.7236, 46.6953);
    distanceKm = 5.0;
    etaMinutes = 10;
    destination = "Error loading destination";

    // Add basic markers
    markers.clear();
    markers.addAll([
      Marker(
        point: currentLocation,
        width: 40,
        height: 40,
        child: Image.asset('assets/images/car.png', width: 40, height: 40),
      ),
      Marker(
        point: destinationLocation,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_pin, color: Colors.blue, size: 40),
      ),
    ]);

    // Add simple route
    routePolyline.clear();
    routePolyline.add(
      Polyline(
        points: [currentLocation, destinationLocation],
        color: Colors.red, // Red to indicate error
        strokeWidth: 4,
      ),
    );

    update();
  }

  Future<void> updateDriverLocation() async {
    if (rideId == null || rideId!.isEmpty) return;

    // Skip update if location permission is not granted
    if (!locationPermissionGranted.value) {
      dev.log("⚠️ Skipping location update: No permission");
      return;
    }

    try {
      // Get current location
      Position position;
      try {
        position = await Geolocator.getCurrentPosition();

        // Validate the coordinates
        if (position.latitude < -90 ||
            position.latitude > 90 ||
            position.longitude < -180 ||
            position.longitude > 180) {
          dev.log(
            "⚠️ Invalid coordinates from Geolocator: lat=${position.latitude}, lng=${position.longitude}",
          );
          // Use simulated position instead
          throw Exception("Invalid coordinates from Geolocator");
        }
      } catch (locationError) {
        dev.log(
          "⚠️ Error getting position: $locationError, using simulated position",
        );
        // If Windows location fails, use simulated position with small random movement
        double latOffset = (math.Random().nextDouble() - 0.5) * 0.0005;
        double lngOffset = (math.Random().nextDouble() - 0.5) * 0.0005;

        // Ensure the current location is valid before applying offset
        double baseLat = currentLocation.latitude;
        double baseLng = currentLocation.longitude;

        if (baseLat < -90 || baseLat > 90) {
          baseLat = 24.7136; // Default latitude if current is invalid
        }

        if (baseLng < -180 || baseLng > 180) {
          baseLng = 46.6753; // Default longitude if current is invalid
        }

        position = Position(
          latitude: baseLat + latOffset,
          longitude: baseLng + lngOffset,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }

      final newLocation = LatLng(position.latitude, position.longitude);

      // Update marker position
      if (markers.isNotEmpty) {
        markers[0] = Marker(
          point: newLocation,
          width: 40,
          height: 40,
          child: Image.asset('assets/images/car.png', width: 40, height: 40),
        );
      }

      // Update current location
      currentLocation = newLocation;

      // Update route info when location has changed significantly
      if (_computeDistanceKm(currentLocation, markers[0].point) > 0.1) {
        _getRouteInfoFromOpenRouteService();
      } else {
        // Simple update for minor movements
        distanceKm = _computeDistanceKm(currentLocation, destinationLocation);
        const avgSpeedKmh = 30.0;
        etaMinutes = (distanceKm / avgSpeedKmh * 60).round();
      }

      // Send updated location to server
      final token = Get.find<AuthController>().token.value;
      await http.post(
        Uri.parse("${ApiEndpoints.baseUrl}/driver/update/location"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "rideId": rideId,
          "location": {"lat": position.latitude, "lng": position.longitude},
        }),
      );

      update();
    } catch (e) {
      dev.log("❌ Error updating driver location: $e");

      // Check if this is a permission error
      if (e.toString().contains("permission")) {
        locationPermissionGranted.value = false;
        _showLocationPermissionError();
      }
    }
  }

  Future<void> refreshRideStatus() async {
    if (rideId == null || rideId!.isEmpty) return;

    try {
      final token = Get.find<AuthController>().token.value;
      final response = await http.get(
        Uri.parse("${ApiEndpoints.baseUrl}/driver/ride/$rideId/status"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) return;

      final statusData = jsonDecode(response.body);

      // Check if ride is completed or cancelled
      if (statusData['status'] == 'completed') {
        // Stop all timers
        _locationUpdateTimer?.cancel();
        _rideStatusTimer?.cancel();
        _pendingRequestsTimer?.cancel();
        _destinationCheckTimer?.cancel();

        // Navigate back with success message
        Get.back();
        Get.snackbar(
          'Ride Completed',
          'You have reached the destination',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else if (statusData['status'] == 'cancelled') {
        // Stop all timers
        _locationUpdateTimer?.cancel();
        _rideStatusTimer?.cancel();
        _pendingRequestsTimer?.cancel();
        _destinationCheckTimer?.cancel();

        // Navigate back with cancellation message
        Get.back();
        Get.snackbar(
          'Ride Cancelled',
          'This ride has been cancelled',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }

      // Update passengers list if available
      if (statusData['passengers'] != null &&
          statusData['passengers'] is List) {
        passengers.clear();
        for (var passenger in statusData['passengers']) {
          passengers.add({
            'id': passenger['_id'] ?? '',
            'name': passenger['name'] ?? 'Passenger',
            'rating': passenger['rating'] ?? 5.0,
            'profilePic':
                passenger['profilePic'] ?? 'https://via.placeholder.com/150',
            'pickedUp': passenger['pickedUp'] ?? false,
            'droppedOff': passenger['droppedOff'] ?? false,
            'pickup': passenger['pickup'] ?? 'Current location',
            'dropoff': passenger['dropoff'] ?? 'Destination',
            'pickupLocation': passenger['pickupLocation'] != null 
                ? LatLng(passenger['pickupLocation']['lat'], passenger['pickupLocation']['lng']) 
                : null,
            'dropoffLocation': passenger['dropoffLocation'] != null 
                ? LatLng(passenger['dropoffLocation']['lat'], passenger['dropoffLocation']['lng']) 
                : null,
          });
        }
      }

      update();
    } catch (e) {
      dev.log("❌ Error refreshing ride status: $e");
    }
  }

  Future<void> fetchPendingRequests() async {
    if (rideId == null || rideId!.isEmpty) {
      dev.log("❌ Cannot fetch pending requests: No ride ID available");
      return;
    }

    try {
      // Skip if we already have a pending request
      if (hasPendingRequest.value) {
        dev.log(
          "ℹ️ Skipping pending requests fetch: Already have a pending request",
        );
        return;
      }

      dev.log("🔄 Fetching pending requests for ride ID: $rideId");

      try {
        // Fetch pending requests from API with retry logic built in
        final requests = await _driverService.getPendingRequests(rideId!);

        if (requests.isEmpty) {
          dev.log("ℹ️ No pending requests found");
          return;
        }

        dev.log("✅ Found ${requests.length} pending requests");
        dev.log("📄 First request data: ${requests.first}");

        // Get the newest request
        final request = requests.first;
        dev.log("📝 Processing request: ${request['_id']}");
        
        // Debug the entire request structure
        dev.log("🔍 DEBUG - Full request structure: ${jsonEncode(request)}");

        // Calculate distance between driver and pickup location
        double pickupDistanceKm = 0.0;
        int pickupTimeMinutes = 3; // Default value
        LatLng? pickupLocation;
        LatLng? dropoffLocation;

        try {
          // Debug pickup location data specifically
          dev.log("🔍 DEBUG - Pickup field in request: ${jsonEncode(request['pickup'])}");
          
          // Get pickup location information
          if (request['pickup'] != null &&
              request['pickup']['lat'] != null &&
              request['pickup']['lng'] != null) {
            final pickupLat = request['pickup']['lat'] as double;
            final pickupLng = request['pickup']['lng'] as double;
            pickupLocation = LatLng(pickupLat, pickupLng);
            
            dev.log("🔍 DEBUG - Successfully parsed pickup location: lat=$pickupLat, lng=$pickupLng");

            // Calculate distance to pickup
            pickupDistanceKm = _computeDistanceKm(
              currentLocation,
              pickupLocation,
            );
            dev.log(
              "📍 Pickup distance: ${pickupDistanceKm.toStringAsFixed(2)} km",
            );

            // Add passenger marker to the map with profile pic
            final passengerName = request['client']?['firstName'] != null && request['client']?['lastName'] != null 
                ? "${request['client']['firstName']} ${request['client']['lastName']}"
                : "Passenger";
            final profilePic = request['client']?['profilePic'];
            
            dev.log("🔍 DEBUG - Adding passenger marker for: $passengerName at $pickupLocation");
            
            addPassengerMarker(
              pickupLocation,
              profilePic: profilePic,
              passengerName: passengerName,
            );

            // Estimate pickup time (assuming 30 km/h average speed)
            const avgSpeedKmh = 30.0;
            pickupTimeMinutes = (pickupDistanceKm / avgSpeedKmh * 60).round();
            if (pickupTimeMinutes < 1) pickupTimeMinutes = 1;
            dev.log("⏱️ Estimated pickup time: $pickupTimeMinutes minutes");
          }
          
          // Get dropoff location information
          String dropoffLocationName = "Unknown destination";
          if (request['dropoff'] != null && 
              request['dropoff']['lat'] != null && 
              request['dropoff']['lng'] != null) {
            
            final dropLat = request['dropoff']['lat'];
            final dropLng = request['dropoff']['lng'];
            dropoffLocation = LatLng(dropLat, dropLng);
            
            // Try to get address if available
            if (request['dropoff']['address'] != null && 
                request['dropoff']['address'].toString().isNotEmpty) {
              dropoffLocationName = request['dropoff']['address'];
              dev.log("📍 Using provided dropoff address: $dropoffLocationName");
            } else {
              // Get location name from coordinates
              dev.log("📍 Fetching dropoff location name for coordinates: $dropLat, $dropLng");
              try {
                dropoffLocationName = await _getLocationNameFromCoordinates(dropLat, dropLng);
                dev.log("📍 Successfully fetched dropoff location name: $dropoffLocationName");
              } catch (e) {
                dev.log("⚠️ Error fetching dropoff location name: $e");
                dropoffLocationName = "Location near (${dropLat.toStringAsFixed(4)}, ${dropLng.toStringAsFixed(4)})";
              }
            }
          }
          
          // Get pickup location name if not provided
          String pickupLocationName = "Current location";
          if (request['pickup'] != null) {
            dev.log("🔍 DEBUG - Processing pickup address with fields: ${request['pickup'].keys.toList()}");
            
            if (request['pickup']['address'] != null && 
                request['pickup']['address'].toString().isNotEmpty) {
              pickupLocationName = request['pickup']['address'];
              dev.log("📍 Using provided pickup address: $pickupLocationName");
            } else if (request['pickup']['lat'] != null && 
                      request['pickup']['lng'] != null) {
              // Get location name from coordinates
              final pickupLat = request['pickup']['lat'];
              final pickupLng = request['pickup']['lng'];
              
              // Fetch location name immediately
              dev.log("📍 Fetching pickup location name for coordinates: $pickupLat, $pickupLng");
              try {
                pickupLocationName = await _getLocationNameFromCoordinates(pickupLat, pickupLng);
                dev.log("📍 Successfully fetched pickup location name: $pickupLocationName");
              } catch (e) {
                dev.log("⚠️ Error fetching pickup location name: $e");
                pickupLocationName = "Location near (${pickupLat.toStringAsFixed(4)}, ${pickupLng.toStringAsFixed(4)})";
              }
            }
          } else {
            dev.log("❌ ERROR - Pickup field is null in request");
          }
          
          // Format the location strings for display
          pickupLocationName = formatLocationForDisplay(pickupLocationName);
          dropoffLocationName = formatLocationForDisplay(dropoffLocationName);
          
          // Debug log for pickup location data
          dev.log("📍 Pickup location data: ${request['pickup']}");
          dev.log("🔍 Final pickup address: $pickupLocationName");
          dev.log("🔍 Final dropoff address: $dropoffLocationName");
          
          // Get client information
          String clientFullName = "New Passenger";
          try {
            if (request['client'] != null) {
              final client = request['client'];
              final firstName = client['firstName'] ?? '';
              final lastName = client['lastName'] ?? '';
              if (firstName.isNotEmpty || lastName.isNotEmpty) {
                clientFullName = '$firstName $lastName'.trim();
              }
            }
            dev.log("👤 Client name: $clientFullName");
          } catch (e) {
            dev.log("⚠️ Error getting client name: $e");
          }

          // Get the actual price from the request
          String actualPrice = "EGP 0";
          try {
            final price = request['price'];
            if (price != null) {
              actualPrice = "EGP $price";
              dev.log("💰 Actual ride price: $actualPrice");
            } else {
              dev.log("⚠️ No price found in request, using default");
              actualPrice = "EGP 15-20"; // Default fallback
            }
          } catch (e) {
            dev.log("⚠️ Error getting price from request: $e");
            actualPrice = "EGP 15-20"; // Default fallback
          }

          // Set the pending request with enhanced data
          pendingRequest.value = {
            'id': request['_id'] ?? '',
            'name': clientFullName,
            'profilePic': request['client']?['profilePic'] ?? 'https://via.placeholder.com/150',
            'pickup': pickupLocationName,
            'dropoff': dropoffLocationName,
            'pickupDistanceKm': pickupDistanceKm,
            'pickupTimeMinutes': pickupTimeMinutes,
            'price': actualPrice,
            'pickupLocation': pickupLocation,
            'dropoffLocation': dropoffLocation,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };

          dev.log("✅ Set pending request data: $pendingRequest");

          // Play notification sound
          await _playRequestNotification();

          // Set the pending request flag to show the notification
          hasPendingRequest.value = true;

          // Auto-decline after 30 seconds if not handled
          Future.delayed(const Duration(seconds: 30), () {
            if (hasPendingRequest.value &&
                pendingRequest.isNotEmpty &&
                pendingRequest['id'] == request['_id']) {
              dev.log("⏰ Auto-declining request after timeout");
              declineRequest();
            }
          });
        } catch (e) {
          // Handle specific errors
          dev.log("❌ Error processing request: $e");
          if (e.toString().contains("502") || e.toString().contains("Server temporarily unavailable")) {
            dev.log("⚠️ Server is temporarily unavailable (502): $e");
            
            // Only show the snackbar if we don't already have a pending request
            // to avoid too many notifications
            if (!hasPendingRequest.value && 
                !Get.isSnackbarOpen && 
                requestState.value != RequestState.loading) {
              Get.snackbar(
                'Server Issue',
                'The server is temporarily unavailable. Retrying automatically...',
                backgroundColor: Colors.orange.withValues(alpha: 0.8),
                colorText: Colors.white,
                duration: Duration(seconds: 3),
                snackPosition: SnackPosition.TOP,
              );
            }
          }
        }
      } catch (e) {
        dev.log("❌ Error fetching pending requests: $e");
        
        // Only show the error if we're not already showing a loading state
        // or another snackbar
        if (!Get.isSnackbarOpen && requestState.value != RequestState.loading) {
          Get.snackbar(
            'Connection Error',
            'Could not check for ride requests. Will retry automatically.',
            backgroundColor: Colors.grey[800],
            colorText: Colors.white,
            duration: Duration(seconds: 3),
            snackPosition: SnackPosition.TOP,
          );
        }
      }
    } catch (e) {
      dev.log("❌ Error fetching pending requests: $e");
      
      // Only show the error if we're not already showing a loading state
      // or another snackbar
      if (!Get.isSnackbarOpen && requestState.value != RequestState.loading) {
        Get.snackbar(
          'Connection Error',
          'Could not check for ride requests. Will retry automatically.',
          backgroundColor: Colors.grey[800],
          colorText: Colors.white,
          duration: Duration(seconds: 3),
          snackPosition: SnackPosition.TOP,
        );
      }
    }
  }

  Future<void> _playRequestNotification() async {
    try {
      // You would need to add a sound file to your assets folder
      // And declare it in your pubspec.yaml
      await _audioPlayer.play(AssetSource('sounds/ride_request.mp3'));
    } catch (e) {
      dev.log("❌ Error playing notification sound: $e");
    }
  }

  Future<void> acceptRequest() async {
    if (pendingRequest['id'] == null || pendingRequest['id'].isEmpty) {
      Get.snackbar('Error', 'Invalid request ID');
      return;
    }
    
    dev.log("🚀 Accepting ride request: ${pendingRequest['id']}");
    
    try {
      // Show loading dialog
      Get.dialog(
        Center(child: CircularProgressIndicator(color: Colors.white)),
        barrierDismissible: false,
      );
      
      requestState.value = RequestState.loading;
      
      final requestId = pendingRequest['id'];
      dev.log("📤 Attempting to approve join request with ID: $requestId");
      
      final approved = await _driverService.approveJoinRequest(
        requestId,
        true,
      );
      
      // Close loading dialog
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      
      if (approved) {
        dev.log("✅ Successfully approved request: $requestId");
        
        // Create a copy of the pending request data
        final Map<String, dynamic> passengerData = {...pendingRequest};
        
        // Debug the passenger data before proceeding
        dev.log("🔍 DEBUG - Passenger data before adding to list: ${jsonEncode(passengerData)}");
        
        // If we have coordinates but no address names, try to fetch them
        try {
          // Ensure we have location names for pickup
          if (passengerData['pickupLocation'] != null && 
              (passengerData['pickup'] == 'Current location' || 
               passengerData['pickup'] == 'Unknown location' || 
               passengerData['pickup'].toString().startsWith('Location near'))) {
            final pickupLat = passengerData['pickupLocation'].latitude;
            final pickupLng = passengerData['pickupLocation'].longitude;
            dev.log("🔍 DEBUG - Fetching pickup name for coordinates: $pickupLat, $pickupLng");
            passengerData['pickup'] = await _getLocationNameFromCoordinates(pickupLat, pickupLng);
            dev.log("✅ Updated pickup location name: ${passengerData['pickup']}");
          }
          
          // Ensure we have location names for dropoff
          if ((passengerData['dropoff'] == 'Unknown destination' || 
               passengerData['dropoff'].toString().startsWith('Location near')) &&
              passengerData['dropoffLocation'] != null) {
            final dropoffLat = passengerData['dropoffLocation'].latitude;
            final dropoffLng = passengerData['dropoffLocation'].longitude;
            dev.log("🔍 DEBUG - Fetching dropoff name for coordinates: $dropoffLat, $dropoffLng");
            passengerData['dropoff'] = await _getLocationNameFromCoordinates(dropoffLat, dropoffLng);
            dev.log("✅ Updated dropoff location name: ${passengerData['dropoff']}");
          }
        } catch (e) {
          dev.log("⚠️ Error updating location names: $e");
          // Continue with existing location data - don't block the process for this
        }
        
        // Debug the passenger data after location updates
        dev.log("🔍 DEBUG - Passenger data after updating locations: ${jsonEncode(passengerData)}");
        
        // Add to passengers list with status and location data
        passengers.add({
          ...passengerData,
          'status': 'approved',
          'pickedUp': false,
          'droppedOff': false,
          'pickupLocation': pendingRequest['pickupLocation'], // Add pickup location for marker management
          'dropoffLocation': pendingRequest['dropoffLocation'], // Add dropoff location information
        });
        
        hasPendingRequest.value = false;
        pendingRequest.clear();
        requestState.value = RequestState.online;
        Get.snackbar(
          'Request Accepted',
          'Passenger has been added to your ride',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        dev.log("❌ Failed to approve request: $requestId");
        requestState.value = RequestState.failed;
        Get.snackbar(
          'Error',
          'Failed to approve request. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 5),
          mainButton: TextButton(
            onPressed: () => acceptRequest(),
            child: Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      
      dev.log("❌ Exception in acceptRequest: $e");
      requestState.value = RequestState.failed;
      Get.snackbar(
        'Error',
        'Failed to accept request: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 5),
        mainButton: TextButton(
          onPressed: () => acceptRequest(),
          child: Text('Retry', style: TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  Future<void> declineRequest() async {
    if (pendingRequest['id'] == null || pendingRequest['id'].isEmpty) {
      hasPendingRequest.value = false;
      pendingRequest.clear();
      return;
    }
    
    dev.log("🚫 Declining ride request: ${pendingRequest['id']}");
    
    try {
      // Show loading dialog
      Get.dialog(
        Center(child: CircularProgressIndicator(color: Colors.white)),
        barrierDismissible: false,
      );
      
      requestState.value = RequestState.loading;
      
      final requestId = pendingRequest['id'];
      dev.log("📤 Attempting to decline join request with ID: $requestId");
      
      final declined = await _driverService.approveJoinRequest(
        requestId,
        false,
      );
      
      // Close loading dialog
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      
      hasPendingRequest.value = false;
      pendingRequest.clear();
      requestState.value = RequestState.online;
      
      if (declined) {
        dev.log("✅ Successfully declined request: $requestId");
        Get.snackbar(
          'Request Declined',
          'You have declined the join request',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      } else {
        dev.log("❌ Failed to decline request: $requestId");
        Get.snackbar(
          'Error',
          'Failed to decline request. The request may have been automatically removed.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      
      dev.log("❌ Exception in declineRequest: $e");
      requestState.value = RequestState.failed;
      Get.snackbar(
        'Error',
        'Failed to decline request: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> pickupPassenger(String requestId) async {
    try {
      // Find the passenger data to get their pickup location
      final passengerIndex = passengers.indexWhere((p) => p['id'] == requestId);
      LatLng? pickupLocation;
      
      if (passengerIndex != -1) {
        pickupLocation = passengers[passengerIndex]['pickupLocation'];
        // Note: We're no longer setting the destination to the passenger's dropoff
        // The original ride destination should be maintained
        dev.log("🚗 Picking up passenger while maintaining original ride destination: $destinationLocation");
      }
      
      // Draw route to passenger before pickup
      await drawRouteToPassenger();
      requestState.value = RequestState.loading;
      final pickedUp = await _driverService.pickupPassenger(requestId);
      
      if (pickedUp) {
        // Update passenger status
        if (passengerIndex != -1) {
          passengers[passengerIndex]['pickedUp'] = true;
          
          // Remove the passenger marker from the map
          if (pickupLocation != null) {
            removePassengerMarker(pickupLocation);
          }
          
          // After pickup, update the route back to the original ride destination
          dev.log("✅ Updating route back to the original ride destination");
          
          // Make sure destination marker is properly set
          if (markers.length > 1) {
            // Replace destination marker in case it was changed
            markers[1] = Marker(
              point: destinationLocation,
              width: 40, 
              height: 40,
              child: const Icon(Icons.location_pin, color: Colors.blue, size: 40),
            );
          } else {
            // Add destination marker if not present
            markers.add(Marker(
              point: destinationLocation,
              width: 40,
              height: 40,
              child: const Icon(Icons.location_pin, color: Colors.blue, size: 40),
            ));
          }
          
          // Update route to continue to original destination
          routePolyline.clear();
          routePolyline.add(Polyline(
            points: [currentLocation, destinationLocation],
            color: Colors.blue,
            strokeWidth: 4.0,
          ));
          
          // Update the view
          update();
        }
        
        requestState.value = RequestState.online;
        update();
        Get.snackbar(
          'Passenger Picked Up',
          'You have picked up the passenger',
          backgroundColor: Colors.blue,
          colorText: Colors.white,
        );
      } else {
        requestState.value = RequestState.failed;
        Get.snackbar(
          'Error',
          'Failed to pick up passenger',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      requestState.value = RequestState.failed;
      Get.snackbar(
        'Error',
        'Failed to pick up passenger: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
  
  // Draw route from driver to destination
  Future<void> drawRouteToDestination(LatLng destination) async {
    try {
      dev.log("🗺️ Drawing route to destination: $destination");
      final start = '${currentLocation.longitude},${currentLocation.latitude}';
      final end = '${destination.longitude},${destination.latitude}';
      
      // Update the destination location
      destinationLocation = destination;
      
      // First try OpenRouteService
      try {
        final response = await http.post(
          Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car'),
          headers: {
            'Authorization': openRouteServiceApiKey,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            "coordinates": [
              [currentLocation.longitude, currentLocation.latitude],
              [destination.longitude, destination.latitude],
            ],
            "instructions": true,
            "format": "json",
          }),
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          if (data.containsKey('routes') && data['routes'] is List && data['routes'].isNotEmpty) {
            final route = data['routes'][0];
            
            // Extract distance and duration
            if (route.containsKey('summary')) {
              final summary = route['summary'];
              if (summary.containsKey('distance')) {
                // Distance is in meters, convert to km
                distanceKm = (summary['distance'] / 1000).toDouble();
              }
              
              if (summary.containsKey('duration')) {
                // Duration is in seconds, convert to minutes
                etaMinutes = (summary['duration'] / 60).round();
              }
            }
            
            // Create polyline from route geometry
            if (route.containsKey('geometry')) {
              _createRoutePolylineFromGeometry(route['geometry']);
              update();
              return;
            }
          }
        }
      } catch (e) {
        dev.log("⚠️ OpenRouteService error: $e");
      }
      
      // Fallback to OSRM if OpenRouteService fails
      try {
        final url = 'http://router.project-osrm.org/route/v1/driving/$start;$end?overview=full&geometries=geojson';
        final response = await http.get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));
            
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          if (data.containsKey('routes') && data['routes'] is List && data['routes'].isNotEmpty) {
            final route = data['routes'][0];
            
            // Extract distance and duration if available
            if (route.containsKey('distance')) {
              distanceKm = (route['distance'] / 1000).toDouble();
            }
            
            if (route.containsKey('duration')) {
              etaMinutes = (route['duration'] / 60).round();
            }
            
            // Create polyline from route geometry
            if (route.containsKey('geometry') && route['geometry'].containsKey('coordinates')) {
              final coords = route['geometry']['coordinates'] as List;
              final List<LatLng> points = coords.map((c) => LatLng(c[1], c[0])).toList();
              
              routePolyline.clear();
              routePolyline.add(
                Polyline(points: points, color: Colors.blue, strokeWidth: 5),
              );
              
              update();
              return;
            }
          }
        }
      } catch (e) {
        dev.log("⚠️ OSRM error: $e");
      }
      
      // If all routing services fail, use a straight line
      dev.log("⚠️ All routing services failed, using straight line");
      routePolyline.clear();
      routePolyline.add(
        Polyline(
          points: [currentLocation, destination],
          color: Colors.blue,
          strokeWidth: 4,
        ),
      );
      
      // Set default estimates based on straight-line distance
      distanceKm = _computeDistanceKm(currentLocation, destination);
      etaMinutes = (distanceKm / 30.0 * 60).round(); // 30 km/h avg speed
      
      update();
    } catch (e) {
      dev.log("❌ Error drawing route to destination: $e");
      
      // Fallback to simple straight line
      routePolyline.clear();
      routePolyline.add(
        Polyline(
          points: [currentLocation, destinationLocation],
          color: Colors.red, // Red to indicate error
          strokeWidth: 4,
        ),
      );
      
      update();
    }
  }

  // Method to check if there are any non-picked up passengers and route to destination if none
  Future<void> checkAndRouteToDestination() async {
    try {
      // Check if we have any non-picked up passengers
      bool hasNonPickedUpPassengers = false;
      
      for (var passenger in passengers) {
        if (passenger['pickedUp'] == false) {
          hasNonPickedUpPassengers = true;
          break;
        }
      }
      
      // If no non-picked up passengers, route to destination
      if (!hasNonPickedUpPassengers && passengers.isNotEmpty) {
        dev.log("🚗 No non-picked up passengers found, routing to original destination");
        
        // Draw route to the original destination
        await drawRouteToDestination(destinationLocation);
        
        // Update the UI
        update();
      }
    } catch (e) {
      dev.log("❌ Error in checkAndRouteToDestination: $e");
    }
  }

  Future<void> dropoffPassenger(String requestId) async {
    try {
      requestState.value = RequestState.loading;
      
      // Find the passenger in the list
      final passengerIndex = passengers.indexWhere((p) => p['id'] == requestId);
      
      if (passengerIndex == -1) {
        dev.log("❌ Passenger not found for dropoff: $requestId");
        requestState.value = RequestState.failed;
        Get.snackbar(
          'Error',
          'Passenger not found for dropoff',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      
      // Call the driver service to mark the passenger as dropped off
      final success = await _driverService.dropoffPassenger(requestId);
      
      if (success) {
        dev.log("✅ Successfully marked passenger as dropped off: $requestId");
        
        // Remove the passenger from the list
        passengers.removeAt(passengerIndex);
        
        // Check if we need to route to destination
        await checkAndRouteToDestination();
        
        requestState.value = RequestState.success;
        
        // Show success message
        Get.snackbar(
          'Success',
          'Passenger dropped off successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        dev.log("❌ Failed to mark passenger as dropped off: $requestId");
        requestState.value = RequestState.failed;
        Get.snackbar(
          'Error',
          'Failed to drop off passenger',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      dev.log("❌ Error dropping off passenger: $e");
      requestState.value = RequestState.failed;
      Get.snackbar(
        'Error',
        'Failed to drop off passenger: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
  
  // Utility method to compute distance between two locations
  double _computeDistanceKm(LatLng start, LatLng end) {
    // Calculate distance using Haversine formula
    const double earthRadius = 6371; // in kilometers
    
    final double lat1 = start.latitude * math.pi / 180;
    final double lat2 = end.latitude * math.pi / 180;
    final double dLat = (end.latitude - start.latitude) * math.pi / 180;
    final double dLon = (end.longitude - start.longitude) * math.pi / 180;
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
                    math.cos(lat1) * math.cos(lat2) *
                    math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  // Method to get location name from coordinates
  Future<String> _getLocationNameFromCoordinates(double latitude, double longitude) async {
    try {
      dev.log("🔍 Getting location name for: $latitude, $longitude");
      
      // Try OpenCage Geocoder first
      try {
        final response = await http.get(
          Uri.parse(
            'https://api.opencagedata.com/geocode/v1/json?q=$latitude+$longitude&key=8c0bbd95e01c4d74809e1c5756d446a5&pretty=1',
          ),
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['results'] != null && data['results'].isNotEmpty) {
            final result = data['results'][0];
            if (result['formatted'] != null) {
              final locationName = result['formatted'];
              dev.log("✅ OpenCage geocoding success: $locationName");
              return locationName;
            }
          }
        }
        dev.log("⚠️ OpenCage geocoding failed with status: ${response.statusCode}");
      } catch (e) {
        dev.log("⚠️ OpenCage geocoding error: $e");
      }
      
      // Try Nominatim as fallback (free, no key required)
      try {
        final response = await http.get(
          Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1',
          ),
          headers: {
            'User-Agent': 'Tariqi-App/1.0',
          },
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['display_name'] != null) {
            final locationName = data['display_name'];
            dev.log("✅ Nominatim geocoding success: $locationName");
            return locationName;
          }
        }
        dev.log("⚠️ Nominatim geocoding failed with status: ${response.statusCode}");
      } catch (e) {
        dev.log("⚠️ Nominatim geocoding error: $e");
      }
      
      // If all else fails, return a formatted coordinate string but more user-friendly
      dev.log("⚠️ All geocoding services failed, using formatted coordinates");
      return "Location near (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})";
    } catch (e) {
      dev.log("❌ Error getting location name: $e");
      return "Location near (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})";
    }
  }

  // A utility method to format location strings for display
  String formatLocationForDisplay(String? locationStr) {
    if (locationStr == null || locationStr.isEmpty) {
      return "Unknown location";
    }
    
    // Handle raw coordinates pattern
    if (locationStr.contains("(") && locationStr.contains(")") && locationStr.contains(",")) {
      // If it's already a friendly "Location near..." format, keep it
      if (locationStr.startsWith("Location near")) {
        return locationStr;
      }
      
      // Extract coordinates for a cleaner display
      final regex = RegExp(r'\((-?\d+\.\d+),\s*(-?\d+\.\d+)\)');
      final match = regex.firstMatch(locationStr);
      
      if (match != null) {
        final lat = double.tryParse(match.group(1) ?? "0.0") ?? 0.0;
        final lng = double.tryParse(match.group(2) ?? "0.0") ?? 0.0;
        return "Location near (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})";
      }
    }
    
    // If it's very long (over 35 chars), truncate with ellipsis
    if (locationStr.length > 35) {
      return "${locationStr.substring(0, 32)}...";
    }
    
    return locationStr;
  }

  // Draw route from driver to passenger
  Future<void> drawRouteToPassenger([LatLng? specificPickupLocation]) async {
    // Use the provided pickup location or fallback to the default passenger pickup location
    final LatLng? pickupLocation = specificPickupLocation ?? passengerPickupLocation;
    
    if (pickupLocation == null) {
      dev.log("❌ No pickup location to draw route to");
      return;
    }
    
    dev.log("🔍 Drawing route to passenger at: $pickupLocation");
    
    final start = '${currentLocation.longitude},${currentLocation.latitude}';
    final end = '${pickupLocation.longitude},${pickupLocation.latitude}';
    final url = 'http://router.project-osrm.org/route/v1/driving/$start;$end?overview=full&geometries=geojson';
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        final List<LatLng> points = coords.map((c) => LatLng(c[1], c[0])).toList();
        
        // Update the route polyline
        routePolyline.clear();
        routePolyline.add(
          Polyline(points: points, color: Colors.blue, strokeWidth: 5),
        );
        
        // Update the view
        update();
      } else {
        // Fallback to straight line if API fails
        routePolyline.clear();
        routePolyline.add(
          Polyline(
            points: [currentLocation, pickupLocation],
            color: Colors.blue,
            strokeWidth: 4,
          ),
        );
        update();
      }
    } catch (e) {
      dev.log("❌ Error fetching route to passenger: $e");
      // Fallback to straight line
      routePolyline.clear();
      routePolyline.add(
        Polyline(
          points: [currentLocation, pickupLocation],
          color: Colors.blue,
          strokeWidth: 4,
        ),
      );
      update();
    }
  }

  // Method to add passenger marker to the map
  void addPassengerMarker(LatLng location, {String? profilePic, String passengerName = 'Passenger'}) {
    try {
      // First, check if a marker already exists at this location
      final existingMarkerIndex = markers.indexWhere((m) => m.point == location);
      if (existingMarkerIndex != -1) {
        // Remove the existing marker
        markers.removeAt(existingMarkerIndex);
      }
      
      // Add the new marker
      markers.add(
        Marker(
          point: location,
          width: 65,
          height: 65,
          child: Column(
            children: [
              // Show passenger name
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  passengerName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              // Show passenger profile picture
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue,
                child: profilePic != null && profilePic.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          profilePic,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.person, color: Colors.white, size: 24);
                          },
                        ),
                      )
                    : Icon(Icons.person, color: Colors.white, size: 24),
              ),
            ],
          ),
        ),
      );
      
      update();
    } catch (e) {
      dev.log("❌ Error adding passenger marker: $e");
    }
  }
  
  // Method to remove passenger marker from the map
  void removePassengerMarker(LatLng location) {
    try {
      // Find and remove the marker at this location
      final markerIndex = markers.indexWhere((m) => m.point == location);
      if (markerIndex != -1) {
        markers.removeAt(markerIndex);
        update();
      }
    } catch (e) {
      dev.log("❌ Error removing passenger marker: $e");
    }
  }

  // Save passenger data for persistence between screen navigations
  Future<void> _savePassengersToService() async {
    if (rideId == null || rideId!.isEmpty || passengers.isEmpty) {
      dev.log("⚠️ Not saving passengers: No ride ID or empty passenger list");
      return;
    }
    
    try {
      // Convert LatLng objects to serializable format
      final List<Map<String, dynamic>> serializablePassengers = [];
      
      for (var passenger in passengers) {
        final Map<String, dynamic> serializedPassenger = Map.from(passenger);
        
        // Convert LatLng to Map for pickup location
        if (passenger['pickupLocation'] != null) {
          final LatLng pickupLoc = passenger['pickupLocation'] as LatLng;
          serializedPassenger['pickupLocation'] = {
            'lat': pickupLoc.latitude,
            'lng': pickupLoc.longitude
          };
        }
        
        // Convert LatLng to Map for dropoff location
        if (passenger['dropoffLocation'] != null) {
          final LatLng dropoffLoc = passenger['dropoffLocation'] as LatLng;
          serializedPassenger['dropoffLocation'] = {
            'lat': dropoffLoc.latitude,
            'lng': dropoffLoc.longitude
          };
        }
        
        serializablePassengers.add(serializedPassenger);
      }
      
      // Save to driver service
      await _driverService.savePassengers(rideId!, serializablePassengers);
      dev.log("✅ Saved ${passengers.length} passengers for ride $rideId to service");
    } catch (e) {
      dev.log("❌ Error saving passengers: $e");
    }
  }
  
  // Load saved passenger data from service
  Future<void> _loadSavedPassengerData() async {
    if (rideId == null || rideId!.isEmpty) {
      dev.log("⚠️ Not loading passengers: No ride ID available");
      return;
    }
    
    try {
      final savedPassengers = await _driverService.getSavedPassengers(rideId!);
      if (savedPassengers != null && savedPassengers.isNotEmpty) {
        // Process passengers, converting saved location data to LatLng objects
        final List<Map<String, dynamic>> processedPassengers = [];
        
        for (var passenger in savedPassengers) {
          final Map<String, dynamic> processedPassenger = Map.from(passenger);
          
          // Convert pickup location map to LatLng
          if (passenger['pickupLocation'] != null) {
            final pickupMap = passenger['pickupLocation'] as Map<String, dynamic>;
            if (pickupMap.containsKey('lat') && pickupMap.containsKey('lng')) {
              processedPassenger['pickupLocation'] = LatLng(
                pickupMap['lat'] as double,
                pickupMap['lng'] as double
              );
            } else {
              processedPassenger['pickupLocation'] = null;
            }
          }
          
          // Convert dropoff location map to LatLng
          if (passenger['dropoffLocation'] != null) {
            final dropoffMap = passenger['dropoffLocation'] as Map<String, dynamic>;
            if (dropoffMap.containsKey('lat') && dropoffMap.containsKey('lng')) {
              processedPassenger['dropoffLocation'] = LatLng(
                dropoffMap['lat'] as double,
                dropoffMap['lng'] as double
              );
            } else {
              processedPassenger['dropoffLocation'] = null;
            }
          }
          
          processedPassengers.add(processedPassenger);
        }
        
        passengers.clear();
        passengers.addAll(processedPassengers);
        dev.log("✅ Loaded ${passengers.length} saved passengers for ride $rideId");
        
        // Add markers for non-picked up passengers
        for (var passenger in passengers) {
          if (passenger['pickedUp'] == false && passenger['pickupLocation'] != null) {
            addPassengerMarker(
              passenger['pickupLocation'] as LatLng,
              profilePic: passenger['profilePic'],
              passengerName: passenger['name'] ?? 'Passenger'
            );
          }
        }
      } else {
        dev.log("ℹ️ No saved passengers found for ride $rideId");
      }
    } catch (e) {
      dev.log("❌ Error loading saved passengers: $e");
    }
  }

  // Implement endRide method to end the current ride
  Future<void> endRide() async {
    try {
      requestState.value = RequestState.loading;
      dev.log("🛑 Ending ride: $rideId");
      
      final success = await _driverService.endRide(rideId!);
      
      if (success) {
        dev.log("✅ Successfully ended ride: $rideId");
        
        // Clear passengers and saved data
        passengers.clear();
        await _driverService.clearSavedPassengers(rideId!);
        
        // Stop all timers
        _locationUpdateTimer?.cancel();
        _rideStatusTimer?.cancel();
        _pendingRequestsTimer?.cancel();
        _destinationCheckTimer?.cancel();
        
        // Navigate back to driver home
        Get.offNamed('/driver-home');
        
        Get.snackbar(
          'Ride Ended',
          'You have successfully ended the ride',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        dev.log("❌ Failed to end ride: $rideId");
        requestState.value = RequestState.failed;
        
        Get.snackbar(
          'Error',
          'Failed to end ride. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 5),
          mainButton: TextButton(
            onPressed: () => endRide(),
            child: Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        );
      }
    } catch (e) {
      dev.log("❌ Error ending ride: $e");
      requestState.value = RequestState.failed;
      
      Get.snackbar(
        'Error',
        'Failed to end ride: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 5),
        mainButton: TextButton(
          onPressed: () => endRide(),
          child: Text('Retry', style: TextStyle(color: Colors.white)),
        ),
      );
    }
  }
}

class ChatController extends GetxController {
  RxList<ChatMessage> messages = <ChatMessage>[].obs;
  RxBool loading = false.obs;
  String rideId;

  ChatController(this.rideId);

  Future<void> loadMessages() async {
    loading.value = true;
    try {
      final token = Get.find<AuthController>().token.value;
      messages.value = await ChatService.fetchMessages(token, rideId);
    } catch (e) {
      // Handle error
    } finally {
      loading.value = false;
    }
  }

  Future<void> sendMessage(String message) async {
    final token = Get.find<AuthController>().token.value;
    // Check if there are any passengers before sending a message
    try {
      final driverActiveRideController = Get.find<DriverActiveRideController>();
      if (driverActiveRideController.passengers.isEmpty) {
        Get.snackbar(
          'Error',
          'No passengers to send chat to',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      
      // Get driver profile to use their name
      try {
        final driverService = Get.find<DriverService>();
        final profile = await driverService.getDriverProfile();
        final firstName = profile['firstName'] ?? '';
        final lastName = profile['lastName'] ?? '';
        dev.log("📤 Sending message as driver: $firstName $lastName");
      } catch (e) {
        dev.log("⚠️ Could not get driver profile: $e");
      }
    } catch (_) {
      // If controller not found, fallback to error
      Get.snackbar(
        'Error',
        'No passengers to send chat to',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    try {
      // Always try to create the chat room first to ensure it exists
      await ChatService.createChatRoom(token, rideId);
      await ChatService.sendMessage(token, rideId, message);
    } catch (e) {
      // If there's still an error, show it to the user
      Get.snackbar(
        'Error',
        'Failed to send message: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    // Try to load messages even if there was an error
    try {
      await loadMessages();
    } catch (e) {
      // Silently handle loading error
    }
  }

  Future<void> createChatRoom() async {
    final token = Get.find<AuthController>().token.value;
    await ChatService.createChatRoom(token, rideId);
  }
}
