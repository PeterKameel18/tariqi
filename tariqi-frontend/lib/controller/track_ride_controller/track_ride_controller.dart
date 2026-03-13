import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:tariqi/client_repo/client_rides_repo.dart';
import 'package:tariqi/client_repo/get_routes_repo.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/const/functions/location_display_helper.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/models/user_rides_model.dart';
import 'package:tariqi/web_services/dio_config.dart';

class TrackRideController extends GetxController {
  TrackRideController({
    GetRoutesRepo? getRoutesRepo,
    ClientRidesRepo? clientRidesRepo,
  }) : getRoutesRepo = getRoutesRepo ?? GetRoutesRepo(dioClient: DioClient()),
       clientRidesRepo =
           clientRidesRepo ?? ClientRidesRepo(dioClient: DioClient());

  final Rx<RequestState> requestState = RequestState.loading.obs;
  final RxList<LatLng> routes = RxList<LatLng>([]);
  final RxList<Marker> markers = RxList<Marker>([]);
  final RxDouble distance = 0.0.obs;
  final RxInt etaMinutes = 0.obs;
  final RxString liveStatusText = "Waiting for driver location".obs;
  final RxString ridePhase = "waiting_pickup".obs;
  final RxString pickupLabel = "Pickup location".obs;
  final RxString dropoffLabel = "Destination".obs;
  final RxString driverName = "Driver details unavailable".obs;
  final RxString driverCarLabel = "Vehicle details unavailable".obs;
  final RxString liveSupportText = "Live trip details will appear here.".obs;

  late MapController mapController;

  final GetRoutesRepo getRoutesRepo;
  final ClientRidesRepo clientRidesRepo;

  List<Routes> route = [];
  String rideId = "";

  Position userPosition = Position(
    longitude: 31.231865086027796,
    latitude: 30.042687574993323,
    timestamp: DateTime.now(),
    accuracy: 0.0,
    altitude: 0.0,
    altitudeAccuracy: 0.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );

  StreamSubscription<Position>? positionStream;
  Timer? _liveRideRefreshTimer;
  bool _hasHandledTerminalTransition = false;

  LatLng? _driverLocation;
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;

  LatLng? _latLngFromDynamic(dynamic value) {
    if (value is LatLng) return value;
    if (value is Routes && value.lat != null && value.lng != null) {
      return LatLng(value.lat!, value.lng!);
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final lat = map['lat'];
      final lng = map['lng'];
      if (lat is num && lng is num) {
        return LatLng(lat.toDouble(), lng.toDouble());
      }
    }
    return null;
  }

  Marker _buildPickupMarker(LatLng point) {
    return Marker(
      point: point,
      child: Icon(
        Icons.location_on_rounded,
        color: AppColors.blueColor,
        size: 34,
      ),
    );
  }

  Marker _buildDriverMarker(LatLng point) {
    return Marker(
      point: point,
      child: Icon(
        Icons.directions_car_rounded,
        color: AppColors.primaryBlue,
        size: 30,
      ),
    );
  }

  void _clearLiveRideUiState() {
    routes.clear();
    markers.clear();
    distance.value = 0.0;
    etaMinutes.value = 0;
    liveStatusText.value = "Trip completed";
    ridePhase.value = "finished";
    pickupLabel.value = "Pickup location";
    dropoffLabel.value = "Destination";
    driverName.value = "Driver details unavailable";
    driverCarLabel.value = "Vehicle details unavailable";
    liveSupportText.value = "Live trip details will appear here.";
    requestState.value = RequestState.none;
    update();
  }

  String _formatDriverName(Map<String, dynamic>? driver) {
    if (driver == null) return "Driver details unavailable";
    final firstName = (driver['firstName'] ?? '').toString().trim();
    final lastName = (driver['lastName'] ?? '').toString().trim();
    final fullName = '$firstName $lastName'.trim();
    return fullName.isEmpty ? "Driver details unavailable" : fullName;
  }

  String _formatDriverCar(Map<String, dynamic>? driver) {
    if (driver == null) return "Vehicle details unavailable";
    final carDetails =
        driver['carDetails'] is Map ? Map<String, dynamic>.from(driver['carDetails']) : null;
    final make = (carDetails?['make'] ?? '').toString().trim();
    final model = (carDetails?['model'] ?? '').toString().trim();
    final plate = (carDetails?['licensePlate'] ?? '').toString().trim();

    final title = '$make $model'.trim();
    if (title.isEmpty && plate.isEmpty) {
      return "Vehicle details unavailable";
    }
    if (plate.isEmpty) {
      return title;
    }
    if (title.isEmpty) {
      return plate;
    }
    return '$title • $plate';
  }

  String _phaseStatusText(String phase) {
    switch (phase) {
      case 'driver_arriving':
        return 'Driver is heading to your pickup';
      case 'onboard':
        return 'You are onboard';
      case 'finished':
        return 'Trip completed';
      case 'waiting_pickup':
      default:
        return 'Waiting for pickup';
    }
  }

  String phaseSupportText(String phase) {
    switch (phase) {
      case 'driver_arriving':
        return 'Follow your driver as they approach the pickup point.';
      case 'onboard':
        return 'You are in the ride now. The route updates as the trip continues.';
      case 'finished':
        return 'This trip has ended and will remain in your history.';
      case 'waiting_pickup':
      default:
        return 'We are syncing driver location, ETA, and route details.';
    }
  }

  String phaseChipLabel(String phase) {
    switch (phase) {
      case 'driver_arriving':
        return 'DRIVER ARRIVING';
      case 'onboard':
        return 'ONBOARD';
      case 'finished':
        return 'FINISHED';
      case 'waiting_pickup':
      default:
        return 'WAITING PICKUP';
    }
  }

  String get distanceDisplay {
    if (distance.value <= 0) {
      return "Live route updating";
    }
    return '${(distance.value / 1000).toStringAsFixed(2)} km away';
  }

  String get etaDisplay {
    if (etaMinutes.value <= 0) {
      return "Estimating";
    }
    return '${etaMinutes.value} min';
  }

  Future<bool> _clientStillHasActiveTrip() async {
    final ridesResponse = await clientRidesRepo.getRides();
    if (!ridesResponse.isRight) {
      dev.log("TRACK_RIDE: could not verify active trip state from trips API");
      return true;
    }

    final rides = ridesResponse.right['rides'];
    if (rides is! List) {
      return true;
    }

    final hasActiveRide = rides.any((ride) {
      if (ride is! Map) return false;
      final rideMap = Map<String, dynamic>.from(ride);
      final rideStatus = (rideMap['status'] ?? '').toString().toLowerCase();
      return rideMap['rideId'] == rideId &&
          (rideStatus == 'accepted' || rideStatus == 'active' || rideStatus == 'pending');
    });

    dev.log(
      "TRACK_RIDE: trips API active check rideId=$rideId hasActiveRide=$hasActiveRide",
    );
    return hasActiveRide;
  }

  Future<void> _handleTerminalTripTransition(String reason) async {
    if (_hasHandledTerminalTransition || isClosed) return;
    _hasHandledTerminalTransition = true;

    dev.log("TRACK_RIDE: terminal transition reason=$reason rideId=$rideId");
    _liveRideRefreshTimer?.cancel();
    _clearLiveRideUiState();

    if (Get.currentRoute != AppRoutesNames.userTripsScreen) {
      Get.offNamed(AppRoutesNames.userTripsScreen);
    }
  }

  void _fitMarkers(List<LatLng> points) {
    if (points.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      mapController.fitCamera(
        CameraFit.coordinates(
          maxZoom: 15,
          padding: EdgeInsets.all(ScreenSize.screenWidth! * 0.1),
          coordinates: points,
        ),
      );
    });
  }

  void initialMapService() {
    if (route.isEmpty || !route.every((e) => e.lat != null && e.lng != null)) {
      requestState.value = RequestState.none;
      return;
    }

    final points = route.map((e) => LatLng(e.lat!, e.lng!)).toList();
    markers
      ..clear()
      ..addAll([
        _buildPickupMarker(points.first),
        _buildDriverMarker(points.last),
      ]);
    _fitMarkers(points);

    getRoutes(
      pickLat: points.first.latitude,
      pickLong: points.first.longitude,
      dropLat: points.last.latitude,
      dropLong: points.last.longitude,
    );

    requestState.value = RequestState.success;
  }

  Future<void> getRoutes({
    required double pickLat,
    required double pickLong,
    required double dropLat,
    required double dropLong,
  }) async {
    try {
      routes.value = [];
      final response = await getRoutesRepo.getRoutes(
        lat1: pickLat,
        long1: pickLong,
        lat2: dropLat,
        long2: dropLong,
      );

      if (response.isNotEmpty) {
        routes.value = response.map((e) => LatLng(e[1], e[0])).toList();
      } else {
        routes.value = [];
      }
    } catch (e) {
      dev.log("TRACK_RIDE: route fetch failed $e");
      routes.value = [];
    }

    update();
  }

  Future<void> _updateClientLocation(Position position) async {
    final updated = await clientRidesRepo.updateCurrentLocation(
      lat: position.latitude,
      lng: position.longitude,
    );
    dev.log(
      "TRACK_RIDE: client location push updated=$updated lat=${position.latitude} lng=${position.longitude}",
    );
  }

  void startTracking() {
    positionStream = Geolocator.getPositionStream().listen((position) async {
      userPosition = position;
      await _updateClientLocation(position);
    });
  }

  Future<void> refreshLiveRideData({bool showLoading = false}) async {
    if (rideId.isEmpty) {
      dev.log("TRACK_RIDE: skipping refresh, empty rideId");
      requestState.value = RequestState.none;
      return;
    }

    if (showLoading) {
      requestState.value = RequestState.loading;
    }

    dev.log("TRACK_RIDE: refreshing live data rideId=$rideId");
    final response = await clientRidesRepo.getRideLiveData(rideId: rideId);
    if (response.isLeft) {
      dev.log("TRACK_RIDE: live data fetch failed rideId=$rideId");
      final stillActive = await _clientStillHasActiveTrip();
      if (!stillActive) {
        await _handleTerminalTripTransition('liveEndpointNoLongerAuthorized');
        return;
      }
      liveStatusText.value = "Live ride details are updating";
      liveSupportText.value = phaseSupportText(ridePhase.value);
      if (pickupLabel.value.trim().isEmpty ||
          pickupLabel.value == "Pickup location") {
        pickupLabel.value = "Pickup details will appear soon";
      }
      if (dropoffLabel.value.trim().isEmpty ||
          dropoffLabel.value == "Destination") {
        dropoffLabel.value = "Destination details will appear soon";
      }
      requestState.value = RequestState.success;
      return;
    }

    final data = response.right;
    dev.log("TRACK_RIDE: live data payload=$data");

    final locations = data['locations'] is List
        ? List<Map<String, dynamic>>.from(
            (data['locations'] as List).whereType<Map>(),
          )
        : <Map<String, dynamic>>[];
    final driverLocationEntry = locations.cast<Map<String, dynamic>?>().firstWhere(
          (entry) => entry?['role'] == 'driver',
          orElse: () => null,
        );

    final selfPassenger =
        data['selfPassenger'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(data['selfPassenger'])
            : data['selfPassenger'] is Map
                ? Map<String, dynamic>.from(data['selfPassenger'] as Map)
                : null;

    if (selfPassenger == null || selfPassenger['droppedOff'] == true) {
      await _handleTerminalTripTransition('selfPassengerMissingOrDroppedOff');
      return;
    }

    final driverData =
        data['driver'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(data['driver'])
            : data['driver'] is Map
                ? Map<String, dynamic>.from(data['driver'] as Map)
                : null;
    driverName.value = _formatDriverName(driverData);
    driverCarLabel.value = _formatDriverCar(driverData);

    final backendRidePhase = (data['ridePhase'] ?? '').toString().trim();
    ridePhase.value = backendRidePhase.isEmpty ? 'waiting_pickup' : backendRidePhase;
    liveSupportText.value = phaseSupportText(ridePhase.value);

    _driverLocation = _latLngFromDynamic(driverLocationEntry?['currentLocation']);
    _pickupLocation =
        _latLngFromDynamic(selfPassenger['pickupLocation'] ?? selfPassenger['pickup']);
    _dropoffLocation = _latLngFromDynamic(
      selfPassenger['dropoffLocation'] ?? selfPassenger['dropoff'],
    );
    pickupLabel.value = await LocationDisplayHelper.resolveLabel(
      selfPassenger['pickupLocation'] ?? selfPassenger['pickup'],
      fallback: 'Pickup location',
    );
    dropoffLabel.value = await LocationDisplayHelper.resolveLabel(
      selfPassenger['dropoffLocation'] ?? selfPassenger['dropoff'],
      fallback: 'Destination',
    );

    final bool pickedUp = selfPassenger['pickedUp'] == true;
    final LatLng? targetLocation = pickedUp
        ? (_dropoffLocation ?? _pickupLocation)
        : _pickupLocation;

    if (_driverLocation != null && targetLocation != null) {
      markers
        ..clear()
        ..addAll([
          _buildPickupMarker(targetLocation),
          _buildDriverMarker(_driverLocation!),
        ]);
      _fitMarkers([_driverLocation!, targetLocation]);

      final distanceMeters = Geolocator.distanceBetween(
        _driverLocation!.latitude,
        _driverLocation!.longitude,
        targetLocation.latitude,
        targetLocation.longitude,
      );
      distance.value = distanceMeters;
      final distanceKm = distanceMeters / 1000;
      etaMinutes.value = ((distanceKm / 30.0) * 60).ceil().clamp(1, 180);
      liveStatusText.value = _phaseStatusText(ridePhase.value);

      await getRoutes(
        pickLat: _driverLocation!.latitude,
        pickLong: _driverLocation!.longitude,
        dropLat: targetLocation.latitude,
        dropLong: targetLocation.longitude,
      );
    } else {
      liveStatusText.value = _phaseStatusText(ridePhase.value);
      liveSupportText.value =
          "Waiting for live driver location. The trip is still active.";
      distance.value = 0.0;
      etaMinutes.value = 0;
      dev.log(
        "TRACK_RIDE: incomplete live data driver=$_driverLocation pickup=$_pickupLocation dropoff=$_dropoffLocation",
      );
    }

    requestState.value = RequestState.success;
  }

  Future<void> initialServices() async {
    markers.clear();
    if (Get.arguments != null && Get.arguments['userRidesModel'] is UserRidesModel) {
      final userRide = Get.arguments['userRidesModel'] as UserRidesModel;
      route = userRide.route ?? [];
      rideId = userRide.rideId ?? "";
      dev.log("TRACK_RIDE: init rideId=$rideId routePoints=${route.length}");
    } else {
      route = [];
      rideId = "";
    }

    initialMapService();
    startTracking();
    await refreshLiveRideData(showLoading: true);
    _liveRideRefreshTimer?.cancel();
    _liveRideRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      refreshLiveRideData();
    });
  }

  @override
  void onInit() {
    mapController = MapController();
    super.onInit();
  }

  @override
  void onReady() {
    initialServices();
    super.onReady();
  }

  @override
  void onClose() {
    _liveRideRefreshTimer?.cancel();
    positionStream?.cancel();
    super.onClose();
  }
}
