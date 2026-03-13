// lib/controller/driver/driver_active_ride_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/functions/location_display_helper.dart';
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
  DriverActiveRideController({
    DriverService? driverService,
    this.enableLocationBootstrap = true,
  }) : _injectedDriverService = driverService;

  final DriverService? _injectedDriverService;
  final bool enableLocationBootstrap;
  late DriverService _driverService;
  final Rx<RequestState> requestState = RequestState.loading.obs;
  final RxList<Map<String, dynamic>> passengers = <Map<String, dynamic>>[].obs;

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
  Timer? _destinationCheckTimer;

  final String openRouteServiceApiKey = Secrets.openRouteServiceKey;

  // Passenger pickup location
  LatLng? passengerPickupLocation;

  void _logRideTerminationEntry(String methodName, {String? rideId, String? extra}) {
    final now = DateTime.now().toIso8601String();
    final route = Get.currentRoute;
    final stack = StackTrace.current.toString().split('\n').take(8).join('\n');
    dev.log("🧭 RIDE_TERMINATION_ENTRY method=$methodName rideId=${rideId ?? this.rideId ?? 'null'} route=$route timestamp=$now extra=${extra ?? ''}");
    dev.log("🧭 RIDE_TERMINATION_STACK method=$methodName\n$stack");
  }

  void _setRequestState(RequestState newState, String source, {String? extra}) {
    final previousState = requestState.value;
    requestState.value = newState;
    String currentRideIdForLog = rideId ?? 'null';
    if (currentRideIdForLog == 'null') {
      try {
        if (Get.isRegistered<DriverService>()) {
          currentRideIdForLog = Get.find<DriverService>().currentRideId ?? 'null';
        }
      } catch (_) {}
    }
    dev.log(
      "🧭 REQUEST_STATE source=$source previous=$previousState next=$newState rideId=$currentRideIdForLog extra=${extra ?? ''}",
    );
  }

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
    _setRequestState(RequestState.loading, 'DriverActiveRideController.onInit');

    // Try to find DriverService or create it if not found
    _driverService = _injectedDriverService ?? Get.find<DriverService>();
    dev.log("✅ Found existing DriverService instance");

    // Get the current ride ID from the DriverService
    rideId = _driverService.currentRideId;
    dev.log("🚗 Active Ride Controller - Current ride ID: $rideId");

    // Try to load saved passenger data for this ride if available
    _loadSavedPassengerData();

    if (enableLocationBootstrap) {
      // Initial data loading will be triggered after location permission check
      _checkLocationPermission();
    }
  }

  @visibleForTesting
  DriverService get debugDriverService => _driverService;

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

  void _showSafeSnackbar(
    String title,
    String message, {
    Color? backgroundColor,
    Color? colorText,
    Duration? duration,
    TextButton? mainButton,
  }) {
    if (Get.overlayContext == null) {
      dev.log("⚠️ Skipping snackbar (no overlay): $title");
      return;
    }
    try {
      Get.snackbar(
        title,
        message,
        backgroundColor: backgroundColor,
        colorText: colorText,
        duration: duration,
        mainButton: mainButton,
      );
    } catch (e) {
      dev.log("⚠️ Failed to show snackbar '$title': $e");
    }
  }

  bool _isSnackbarOpenSafe() {
    try {
      return Get.isSnackbarOpen;
    } catch (e) {
      dev.log("⚠️ Failed to read snackbar state: $e");
      return false;
    }
  }

  void _closeCurrentSnackbarSafe() {
    try {
      if (_isSnackbarOpenSafe()) {
        Get.closeCurrentSnackbar();
      }
    } catch (e) {
      dev.log("⚠️ Failed to close snackbar: $e");
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
      _closeCurrentSnackbarSafe();
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
    _showSafeSnackbar(
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
    _destinationCheckTimer?.cancel();
    super.onClose();
  }

  void _startPeriodicUpdates() {
    // Cancel any existing timers first
    _locationUpdateTimer?.cancel();
    _rideStatusTimer?.cancel();
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
        _setRequestState(RequestState.failed, 'DriverActiveRideController.loadRideData.noRideFound');
        _showSafeSnackbar(
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
      _setRequestState(RequestState.loading, 'DriverActiveRideController.loadRideData.start');
      dev.log("🔄 Loading ride data for ride ID: $rideId passengersBefore=${passengers.length}");

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

        // Always refresh passengers from API response when provided
        if (rideData.containsKey('passengers') && rideData['passengers'] is List) {
          dev.log("🔄 Loading passengers from API response currentCount=${passengers.length}");
          passengers.clear();
          for (var passenger in rideData['passengers']) {
            passengers.add({
              'id': passenger['requestId'] ?? passenger['_id'] ?? '',
              'name': passenger['name'] ?? 'Passenger',
              'rating': passenger['rating'] ?? 5.0,
              'profilePic':
                  passenger['profilePic'] ?? 'https://via.placeholder.com/150',
              'price': passenger['price'],
              'pickedUp': passenger['pickedUp'] ?? false,
              'droppedOff': passenger['droppedOff'] ?? false,
              'pickup': await LocationDisplayHelper.resolveLabel(
                passenger['pickup'],
                fallback: 'Current location',
              ),
              'dropoff': await LocationDisplayHelper.resolveLabel(
                passenger['dropoff'],
                fallback: 'Destination',
              ),
              'pickupLocation': passenger['pickupLocation'] != null 
                  ? LatLng(passenger['pickupLocation']['lat'], passenger['pickupLocation']['lng']) 
                  : null,
              'dropoffLocation': passenger['dropoffLocation'] != null 
                  ? LatLng(passenger['dropoffLocation']['lat'], passenger['dropoffLocation']['lng']) 
                  : null,
            });
          }
          dev.log("✅ Successfully loaded ${passengers.length} passengers from API source=service");
          
          // Save the passengers to the service for persistence
          _savePassengersToService();
        }

        _setRequestState(RequestState.online, 'DriverActiveRideController.loadRideData.serviceSuccess');
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
          dev.log("🔄 Loading passengers from direct API response currentCount=${passengers.length}");
          passengers.clear();
          for (var passenger in directRideData['passengers']) {
            passengers.add({
              'id': passenger['requestId'] ?? passenger['_id'] ?? '',
              'name': passenger['name'] ?? 'Passenger',
              'rating': passenger['rating'] ?? 5.0,
              'profilePic':
                  passenger['profilePic'] ?? 'https://via.placeholder.com/150',
              'price': passenger['price'],
              'pickedUp': passenger['pickedUp'] ?? false,
              'droppedOff': passenger['droppedOff'] ?? false,
              'pickup': await LocationDisplayHelper.resolveLabel(
                passenger['pickup'],
                fallback: 'Current location',
              ),
              'dropoff': await LocationDisplayHelper.resolveLabel(
                passenger['dropoff'],
                fallback: 'Destination',
              ),
              'pickupLocation': passenger['pickupLocation'] != null 
                  ? LatLng(passenger['pickupLocation']['lat'], passenger['pickupLocation']['lng']) 
                  : null,
              'dropoffLocation': passenger['dropoffLocation'] != null 
                  ? LatLng(passenger['dropoffLocation']['lat'], passenger['dropoffLocation']['lng']) 
                  : null,
            });
          }
          dev.log("✅ Successfully loaded ${passengers.length} passengers from API source=direct");
          
          // Save the passengers to the service for persistence
          _savePassengersToService();
        }

        _setRequestState(RequestState.online, 'DriverActiveRideController.loadRideData.directSuccess');
        return;
      }

      // If we got here, all attempts failed
      dev.log("❌ Failed to load ride data");
      _setRequestState(RequestState.failed, 'DriverActiveRideController.loadRideData.allAttemptsFailed');

      // Show error with retry button
      _showSafeSnackbar(
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
      _setRequestState(RequestState.failed, 'DriverActiveRideController.loadRideData.exception', extra: e.toString());

      // Show error with retry button
      _showSafeSnackbar(
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
      destination = LocationDisplayHelper.immediateLabel(
        {
          'lat': destinationLocation.latitude,
          'lng': destinationLocation.longitude,
        },
        fallback: 'Destination unavailable',
      );

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
      destination = await LocationDisplayHelper.resolveLabel(
        {
          'lat': destinationLocation.latitude,
          'lng': destinationLocation.longitude,
        },
        fallback: 'Destination unavailable',
      );
      dev.log("✅ Resolved destination label: $destination");
      update();
    } catch (e) {
      dev.log("❌ Error getting destination name: $e");
      destination = LocationDisplayHelper.immediateLabel(
        {
          'lat': destinationLocation.latitude,
          'lng': destinationLocation.longitude,
        },
        fallback: 'Destination unavailable',
      );
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
      final response = await http.post(
        Uri.parse(ApiEndpoints.userSetLocation),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "currentLocation": {
            "lat": position.latitude,
            "lng": position.longitude,
          },
        }),
      );
      dev.log(
        "🧭 DRIVER_LOCATION_UPDATE responseCode=${response.statusCode} rideId=$rideId location=${position.latitude},${position.longitude}",
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

      dev.log("🧭 refreshRideStatus responseCode=${response.statusCode} rideId=$rideId");
      if (response.statusCode != 200) {
        dev.log("⚠️ refreshRideStatus skipped update due to non-200 response");
        return;
      }

      final statusData = jsonDecode(response.body);

      // Check if ride is completed or cancelled
      if (statusData['status'] == 'completed') {
        // Stop all timers
        _locationUpdateTimer?.cancel();
        _rideStatusTimer?.cancel();
        _destinationCheckTimer?.cancel();

        // Navigate back with success message
        Get.back();
        _showSafeSnackbar(
          'Ride Completed',
          'You have reached the destination',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else if (statusData['status'] == 'cancelled') {
        // Stop all timers
        _locationUpdateTimer?.cancel();
        _rideStatusTimer?.cancel();
        _destinationCheckTimer?.cancel();

        // Navigate back with cancellation message
        Get.back();
        _showSafeSnackbar(
          'Ride Cancelled',
          'This ride has been cancelled',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }

      // Update passengers list if available
      if (statusData['passengers'] != null &&
          statusData['passengers'] is List) {
        dev.log("🧭 refreshRideStatus reassigning passengers before=${passengers.length} incoming=${(statusData['passengers'] as List).length}");
        passengers.clear();
        for (var passenger in statusData['passengers']) {
          passengers.add({
            'id': passenger['requestId'] ?? passenger['_id'] ?? '',
            'name': passenger['name'] ?? 'Passenger',
            'rating': passenger['rating'] ?? 5.0,
            'profilePic':
                passenger['profilePic'] ?? 'https://via.placeholder.com/150',
            'price': passenger['price'],
            'pickedUp': passenger['pickedUp'] ?? false,
            'droppedOff': passenger['droppedOff'] ?? false,
            'pickup': await LocationDisplayHelper.resolveLabel(
              passenger['pickup'],
              fallback: 'Current location',
            ),
            'dropoff': await LocationDisplayHelper.resolveLabel(
              passenger['dropoff'],
              fallback: 'Destination',
            ),
            'pickupLocation': passenger['pickupLocation'] != null 
                ? LatLng(passenger['pickupLocation']['lat'], passenger['pickupLocation']['lng']) 
                : null,
            'dropoffLocation': passenger['dropoffLocation'] != null 
                ? LatLng(passenger['dropoffLocation']['lat'], passenger['dropoffLocation']['lng']) 
                : null,
          });
        }
        dev.log("🧭 refreshRideStatus passengersAfter=${passengers.length}");
      }

      update();
    } catch (e) {
      dev.log("❌ Error refreshing ride status: $e");
    }
  }

  // Removed: fetchPendingRequests() - now handled by global DriverService polling

  // Removed: _playRequestNotification() - now handled by global request dialog

  Future<void> recoverAfterDecline(String requestId) async {
    dev.log(
      "🧭 DECLINE_RECOVERY start requestId=$requestId rideId=${rideId ?? _driverService.currentRideId ?? 'null'} requestState=${requestState.value}",
    );
    try {
      await refreshRideStatus();
      dev.log(
        "🧭 DECLINE_RECOVERY refreshRideStatus completed requestId=$requestId requestState=${requestState.value}",
      );
    } catch (e) {
      dev.log("❌ DECLINE_RECOVERY refreshRideStatus failed requestId=$requestId error=$e");
    } finally {
      if (requestState.value == RequestState.loading) {
        _setRequestState(
          RequestState.online,
          'DriverActiveRideController.recoverAfterDecline',
          extra: 'Reset stuck loading after decline for requestId=$requestId',
        );
      } else {
        dev.log(
          "🧭 DECLINE_RECOVERY leaving requestState unchanged requestId=$requestId requestState=${requestState.value}",
        );
      }
      update();
    }
  }

  // Removed: acceptRequest() and declineRequest() - now handled by global request dialog

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
      if (!hasNonPickedUpPassengers) {
        dev.log(
          "🚗 No non-picked up passengers found, routing to original destination passengersRemaining=${passengers.length}",
        );
        
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
        await _savePassengersToService();
        
        // Check if we need to route to destination
        await checkAndRouteToDestination();
        
        requestState.value = RequestState.online;
        update();
        
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
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show passenger name
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  passengerName,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              // Show passenger profile picture
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blue,
                child: profilePic != null && profilePic.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          profilePic,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.person, color: Colors.white, size: 20);
                          },
                        ),
                      )
                    : Icon(Icons.person, color: Colors.white, size: 20),
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
      _logRideTerminationEntry('DriverActiveRideController.endRide');
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
        _destinationCheckTimer?.cancel();
        
        _showSafeSnackbar(
          'Ride Ended',
          'You have successfully ended the ride',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        // Navigate back to driver home
        Get.offNamed('/driver-home');
      } else {
        dev.log("❌ Failed to end ride: $rideId");
        requestState.value = RequestState.failed;
        
        _showSafeSnackbar(
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
      
      _showSafeSnackbar(
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
  RxBool sending = false.obs;
  Timer? _pollingTimer;
  static const Duration _pollingInterval = Duration(seconds: 3);
  String rideId;

  ChatController(this.rideId);

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) async {
      dev.log(
        "🗨️ CHAT polling.tick rideId=$rideId currentCount=${messages.length}",
      );
      await loadMessages(showLoading: false);
    });
  }

  Future<void> loadMessages({bool showLoading = true}) async {
    dev.log(
      "🗨️ CHAT loadMessages.start rideId=$rideId route=${Get.currentRoute} showLoading=$showLoading beforeCount=${messages.length}",
    );
    if (rideId.isEmpty) {
      dev.log("🗨️ CHAT loadMessages.skipped missingRideId");
      messages.clear();
      return;
    }
    if (showLoading) {
      loading.value = true;
    }
    try {
      final token = Get.find<AuthController>().token.value;
      await ChatService.createChatRoom(token, rideId);
      messages.value = await ChatService.fetchMessages(token, rideId);
      dev.log(
        "🗨️ CHAT loadMessages.success rideId=$rideId afterCount=${messages.length}",
      );
    } catch (e) {
      dev.log("🗨️ CHAT loadMessages.failure rideId=$rideId error=$e");
    } finally {
      if (showLoading) {
        loading.value = false;
      }
    }
  }

  Future<void> sendMessage(String message) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty || sending.value) {
      return;
    }

    dev.log("🗨️ CHAT sendMessage.start rideId=$rideId message=$trimmedMessage");
    if (rideId.isEmpty) {
      Get.snackbar(
        'Error',
        'Chat is unavailable because the ride could not be identified.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final token = Get.find<AuthController>().token.value;
    try {
      sending.value = true;
      await ChatService.createChatRoom(token, rideId);
      await ChatService.sendMessage(token, rideId, trimmedMessage);
      dev.log("🗨️ CHAT sendMessage.success rideId=$rideId");
    } catch (e) {
      dev.log("🗨️ CHAT sendMessage.failure rideId=$rideId error=$e");
      Get.snackbar(
        'Error',
        'Failed to send message: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    } finally {
      sending.value = false;
    }

    try {
      await loadMessages();
    } catch (e) {
      dev.log("🗨️ CHAT sendMessage.reloadFailure rideId=$rideId error=$e");
    }
  }

  Future<void> createChatRoom() async {
    final token = Get.find<AuthController>().token.value;
    await ChatService.createChatRoom(token, rideId);
  }

  @override
  void onInit() {
    super.onInit();
    dev.log("🗨️ CHAT controller.onInit rideId=$rideId route=${Get.currentRoute}");
    _startPolling();
  }

  @override
  void onClose() {
    dev.log("🗨️ CHAT controller.onClose rideId=$rideId route=${Get.currentRoute}");
    _pollingTimer?.cancel();
    super.onClose();
  }
}
