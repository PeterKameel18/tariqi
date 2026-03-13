import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tariqi/const/api_links_keys/api_links_keys.dart';

enum DriverSearchState {
  searching,  // Initial state when looking for drivers
  received,   // Driver proposal received, waiting for user to accept/reject
  waiting,    // User accepted, waiting for driver confirmation
  accepted,   // Driver accepted the ride request
  rejected,   // Driver rejected the ride request
}

class SearchDriverController extends GetxController {
  final mapController = MapController();
  final driverMarkers = <Marker>[].obs;
  final Rx<DriverSearchState> searchState = DriverSearchState.searching.obs;
  final timerSeconds = 0.obs;
  final responseTimeRemaining = 20.obs; // Countdown timer for user to respond in seconds
  
  // Current driver proposal
  final RxMap<String, dynamic> proposedDriver = <String, dynamic>{}.obs;
  
  // Selected/Confirmed driver information
  final RxMap<String, dynamic> confirmedDriver = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> confirmedRide = <String, dynamic>{}.obs;
  
  // For movement simulation (before we get real data)
  LatLng driverPosition = LatLng(30.0444, 31.2357);
  
  Timer? _searchTimer;
  Timer? _pollingTimer;
  Timer? _responseTimer;
  Timer? _driverConfirmationTimer;
  Timer? _simulationTimer;

  @override
  void onInit() {
    super.onInit();
    addDriverMarker();
    
    // Start a timer to simulate driver movement
    _simulationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (searchState.value != DriverSearchState.accepted) {
        updateDriverPosition();
      }
    });
  }
  
  void startSearchingForDriver() {
    // Start timer for UI counter
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      timerSeconds.value++;
    });
    
    // Start API polling
    startPollingForDriver();
  }

  void addDriverMarker() {
    driverMarkers.clear();
    driverMarkers.add(
      Marker(
        point: driverPosition,
        child: const Icon(
          Icons.directions_car,
          color: Colors.blue,
          size: 30,
        ),
      ),
    );
  }

  void updateDriverPosition() {
    // Move the driver randomly but generally northeast (for visualization)
    final random = DateTime.now().millisecondsSinceEpoch % 3 - 1;
    driverPosition = LatLng(
      driverPosition.latitude + 0.0001 * (1 + random * 0.5),
      driverPosition.longitude + 0.0001 * (1 + random * 0.5),
    );
    addDriverMarker();
  }
  
  void startPollingForDriver() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (searchState.value == DriverSearchState.searching) {
        await checkForEligibleDriver();
      }
    });
  }

  Future<void> checkForEligibleDriver() async {
    try {
      const String availableDriversUrl = "${ApiLinksKeys.baseUrl}/drivers/available";
      final response = await http.get(Uri.parse(availableDriversUrl));
      
      if (response.statusCode == 200) {
        final drivers = jsonDecode(response.body) as List;
        
        // For demo purposes, just take the first available driver
        if (drivers.isNotEmpty) {
          // Cancel polling while waiting for user to respond
          _pollingTimer?.cancel();
          
          // Update state and show driver proposal
          proposedDriver.assignAll(drivers.first);
          searchState.value = DriverSearchState.received;
          
          // Set timer for user to respond
          responseTimeRemaining.value = 20;
          _startResponseTimer();
        }
      }
    } catch (e) {
      log('Error checking for eligible driver: $e');
      // Continue polling even if there's an error
    }
  }
  
  void _startResponseTimer() {
    _responseTimer?.cancel();
    _responseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (responseTimeRemaining.value > 0) {
        responseTimeRemaining.value--;
      } else {
        // Time's up, automatically reject and continue searching
        rejectDriverProposal();
      }
    });
  }
  
  void acceptDriverProposal() {
    _responseTimer?.cancel();
    searchState.value = DriverSearchState.waiting;
    
    // Send accept request to backend
    _sendUserAcceptance();
    
    // Start polling for driver's confirmation
    _startDriverConfirmationPolling();
  }
  
  void rejectDriverProposal() {
    _responseTimer?.cancel();
    searchState.value = DriverSearchState.searching;
    proposedDriver.clear();
    
    // Resume polling for new drivers
    startPollingForDriver();
  }
  
  Future<void> _sendUserAcceptance() async {
    try {
      const String acceptEndpoint = "${ApiLinksKeys.baseUrl}/rides/accept";
      
      await http.post(
        Uri.parse(acceptEndpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "driverId": proposedDriver["id"],
          "rideId": proposedDriver["rideId"],
        }),
      );
      
      // No need to handle response here - we'll poll for confirmation
    } catch (e) {
      log('Error sending user acceptance: $e');
      // Even if this fails, we'll continue polling for a response
    }
  }
  
  void _startDriverConfirmationPolling() {
    _driverConfirmationTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _checkDriverConfirmation();
    });
  }
  
  Future<void> _checkDriverConfirmation() async {
    if (searchState.value != DriverSearchState.waiting) return;
    
    try {
      final String confirmationUrl = "${ApiLinksKeys.baseUrl}/rides/confirmation/${proposedDriver["rideId"]}";
      
      final response = await http.get(Uri.parse(confirmationUrl));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data["status"]; // "accepted", "rejected", "waiting"
        
        if (status == "accepted") {
          _onRideAccepted(data);
        } else if (status == "rejected") {
          _onRideRejected();
        }
        // If waiting, continue polling
      }
    } catch (e) {
      log('Error checking driver confirmation: $e');
      // Continue polling even if there's an error
    }
  }
  
  void _onRideAccepted(Map<String, dynamic> data) {
    _driverConfirmationTimer?.cancel();
    searchState.value = DriverSearchState.accepted;
    
    // Store confirmed ride and driver details
    confirmedDriver.assignAll(data["driver"] ?? {});
    confirmedRide.assignAll(data["ride"] ?? {});
    
    // Set driver position for map if available
    if (data["driver"] != null && 
        data["driver"]["latitude"] != null && 
        data["driver"]["longitude"] != null) {
      driverPosition = LatLng(
        data["driver"]["latitude"], 
        data["driver"]["longitude"]
      );
      addDriverMarker();
    }
    
    // Center map on driver position
    mapController.move(driverPosition, 15.0);
    
    // Keep the timer going to show elapsed time
  }
  
  void _onRideRejected() {
    _driverConfirmationTimer?.cancel();
    searchState.value = DriverSearchState.rejected;
    
    // Show rejection message
    try { Get.snackbar(
      "Driver Unavailable", 
      "The driver couldn't accept your ride request.",
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    ); } catch (_) { }
    
    // After a brief delay, resume searching
    Future.delayed(const Duration(seconds: 2), () {
      searchState.value = DriverSearchState.searching;
      proposedDriver.clear();
      startPollingForDriver();
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _pollingTimer?.cancel();
    _responseTimer?.cancel();
    _driverConfirmationTimer?.cancel();
    _simulationTimer?.cancel();
    super.dispose();
  }
}