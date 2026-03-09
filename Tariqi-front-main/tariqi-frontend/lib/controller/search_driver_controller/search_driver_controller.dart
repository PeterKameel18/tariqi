import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tariqi/const/api_links_keys/api_links_keys.dart';

class SearchDriverController extends GetxController {
  final mapController = MapController();
  final driverMarkers = <Marker>[].obs;
  final driverFound = false.obs;
  final driverInfo = ''.obs;

  // For movement simulation
  LatLng driverPosition = LatLng(37.7749, -122.4194);

  @override
  void onInit() {
    super.onInit();
    addDriverMarker();
  }

  void addDriverMarker() {
    driverMarkers.clear();
    driverMarkers.add(
      Marker(
        point: driverPosition,
        child: const Icon(Icons.directions_car, color: Colors.blue, size: 30),
      ),
    );
    update();
  }

  void updateDriverPosition() {
    // Move the driver east and north a bit
    driverPosition = LatLng(
      driverPosition.latitude + 0.0002,
      driverPosition.longitude + 0.0002,
    );
    addDriverMarker();
  }

  void setDriverFound() {
    driverFound.value = true;
    driverInfo.value =
        "Driver: Mohamed Ashraf Mohamed\nCar: Red Toyota\nPlate: ABC-123";
  }

  void resetDriverFound() {
    driverFound.value = false;
  }
}

class SearchingDriverController extends GetxController {
  Timer? _pollingTimer;
  final RxMap<String, dynamic> foundDriver = <String, dynamic>{}.obs;
  final RxMap<String, dynamic> foundRide = <String, dynamic>{}.obs;

  @override
  void onInit() {
    super.onInit();
    startPollingForDriver();
  }

  void startPollingForDriver() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await checkForEligibleDriver();
    });
  }

  Future<void> checkForEligibleDriver() async {
    final String ridesUrl = "${ApiLinksKeys.baseUrl}/rides";
    final response = await http.get(Uri.parse(ridesUrl));
    if (response.statusCode == 200) {
      final rides = jsonDecode(response.body) as List;
      final compatibleRide = rides.firstWhereOrNull(
        (ride) =>
            ride['availableSeats'] > 0 && ride['rideStatus'] == 'scheduled',
        // Add more conditions if needed
      );
      if (compatibleRide != null) {
        foundRide.assignAll(compatibleRide);
        await fetchDriverInfo(compatibleRide['driver']);
        _pollingTimer?.cancel();
      }
    }
  }

  Future<void> fetchDriverInfo(String driverId) async {
    final String driverUrl = "${ApiLinksKeys.baseUrl}/drivers/$driverId";
    final response = await http.get(Uri.parse(driverUrl));
    if (response.statusCode == 200) {
      final driver = jsonDecode(response.body);
      foundDriver.assignAll(driver);
    }
  }

  @override
  void onClose() {
    _pollingTimer?.cancel();
    super.onClose();
  }
}
