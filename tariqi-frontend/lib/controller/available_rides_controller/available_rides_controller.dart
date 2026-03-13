import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:tariqi/const/class/notification_type.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/functions/send_notification.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/main.dart';
import 'package:tariqi/client_repo/availaible_rides_repo.dart';
import 'package:tariqi/client_repo/client_rides_repo.dart';
import 'package:tariqi/client_repo/get_routes_repo.dart';
import 'package:tariqi/models/availaible_rides_model.dart';
import 'package:tariqi/web_services/dio_config.dart';

class AvailableRidesController extends GetxController {
  AvailableRidesController({
    GetRoutesRepo? getRoutesRepo,
    ClientAvailableRidesRepo? clientRidesRepo,
    ClientBookRideRepo? clientBookRideRepo,
    ClientRidesRepo? clientTripsRepo,
    void Function(String title, String message)? feedbackHandler,
  }) : getRoutesRepo = getRoutesRepo ??
           GetRoutesRepo(
             dioClient: Get.isRegistered<DioClient>()
                 ? Get.find<DioClient>()
                 : DioClient(),
           ),
       clientRidesRepo =
           clientRidesRepo ??
               ClientAvailableRidesRepo(
                 dioClient: Get.isRegistered<DioClient>()
                     ? Get.find<DioClient>()
                     : DioClient(),
               ),
       clientBookRideRepo =
           clientBookRideRepo ??
               ClientBookRideRepo(
                 dioClient: Get.isRegistered<DioClient>()
                     ? Get.find<DioClient>()
                     : DioClient(),
               ),
       clientTripsRepo =
           clientTripsRepo ??
               ClientRidesRepo(
                 dioClient: Get.isRegistered<DioClient>()
                     ? Get.find<DioClient>()
                     : DioClient(),
               ),
       feedbackHandler = feedbackHandler;

  late MapController mapController;
  double? pickLat;
  double? pickLong;
  double? dropLat;
  double? dropLong;
  String? pickPoint;
  String? targetPoint;
  List<Marker> markers = [];
  Rx<RequestState> requestState = RequestState.none.obs;
  GetRoutesRepo getRoutesRepo;
  ClientAvailableRidesRepo clientRidesRepo;
  ClientBookRideRepo clientBookRideRepo;
  ClientRidesRepo clientTripsRepo;
  final void Function(String title, String message)? feedbackHandler;
  RxList<AvailaibleRidesModel> availableRides = <AvailaibleRidesModel>[].obs;
  RxList<LatLng> routes = RxList<LatLng>([]);

  void _showFeedback(String title, String message) {
    if (feedbackHandler != null) {
      feedbackHandler!(title, message);
      return;
    }
    try {
      Get.snackbar(title, message);
    } catch (e) {
      log("AVAILABLE_RIDES feedback error: $e");
    }
  }

  bool _hasBlockingTripStatus(String? status) {
    final normalized = (status ?? '').toLowerCase();
    return normalized == 'pending' ||
        normalized == 'accepted' ||
        normalized == 'active';
  }

  Future<String?> _getRideRequestBlockReason() async {
    final ridesResponse = await clientTripsRepo.getRides();
    if (!ridesResponse.isRight) {
      return null;
    }

    final rides = ridesResponse.right['rides'];
    if (rides is! List) {
      return null;
    }

    final hasBlockingRide = rides.whereType<Map>().any((ride) {
      final rideMap = Map<String, dynamic>.from(ride);
      return _hasBlockingTripStatus(rideMap['status']?.toString());
    });

    if (!hasBlockingRide) {
      return null;
    }

    return "You already have an active or pending ride. Finish or cancel it before requesting another one.";
  }

  void assignMarkers() {
    if (pickLat == null || pickLong == null) {
      log("assignMarkers skipped: pickup coordinates are missing");
      return;
    }
    requestState.value = RequestState.loading;
    markers.add(
      Marker(
        point: LatLng(pickLat!, pickLong!),
        child: Icon(Icons.location_on, color: AppColors.blueColor, size: 30),
      ),
    );

    mapController.move(LatLng(pickLat!, pickLong!), 12);

    requestState.value = RequestState.success;
    update();
  }

  Future<void> getRoutes({
    required double driverLat,
    required double driverLong,
  }) async {
    if (!_isValidCoordinate(driverLat, driverLong) ||
        !_isValidCoordinate(pickLat, pickLong)) {
      routes.value = [];
      requestState.value = RequestState.none;
      return;
    }
    requestState.value = RequestState.loading;
    try {
      var response = await getRoutesRepo.getRoutes(
        lat1: pickLat!,
        long1: pickLong!,
        lat2: driverLat,
        long2: driverLong,
      );

      if (response.isNotEmpty) {
        routes.value = response
            .whereType<List>()
            .map((e) => e.length >= 2 ? LatLng(e[1], e[0]) : null)
            .whereType<LatLng>()
            .where(
              (point) =>
                  point.latitude.isFinite && point.longitude.isFinite,
            )
            .toList();
        requestState.value = routes.isNotEmpty
            ? RequestState.success
            : RequestState.none;
      } else {
        routes.value = [];
        requestState.value = RequestState.none;
      }
    } catch (e) {
      try { Get.snackbar("Failed", "Error getting routes $e"); } catch (_) { }
    }
  }

  void previewDriverRoute({required AvailaibleRidesModel ride}) {
    final routePoints = ride.driverRoute;
    if (routePoints == null || routePoints.length < 2) {
      try {
        Get.snackbar("Route unavailable", "Driver route is not available");
      } catch (_) {}
      return;
    }

    final points = routePoints
        .where((point) => _isValidCoordinate(point.lat, point.lng))
        .map((point) => LatLng(point.lat!, point.lng!))
        .toList();

    if (points.length < 2) {
      try {
        Get.snackbar("Route unavailable", "Driver route has invalid coordinates");
      } catch (_) {}
      return;
    }

    routes.assignAll(points);
    markers
      ..clear()
      ..add(
        Marker(
          point: points.first,
          child: Icon(Icons.car_rental, color: AppColors.greenColor, size: 35),
        ),
      )
      ..add(
        Marker(
          point: points.last,
          child: Icon(Icons.flag_rounded, color: AppColors.primaryBlue, size: 32),
        ),
      );

    mapController.fitCamera(
      CameraFit.coordinates(
        forceIntegerZoomLevel: true,
        coordinates: points,
      ),
    );
    requestState.value = RequestState.success;
    update();
  }

  getAvailaibleRides() async {
    log(
      "clientGetRides start coords: pick=($pickLat,$pickLong) drop=($dropLat,$dropLong)",
    );
    if (pickLat == null ||
        pickLong == null ||
        dropLat == null ||
        dropLong == null) {
      log(
        "clientGetRides skipped: missing coords pick=($pickLat,$pickLong) drop=($dropLat,$dropLong)",
      );
      requestState.value = RequestState.failed;
      return;
    }
    requestState.value = RequestState.loading;
    log("clientGetRides requestState -> ${requestState.value}");
    try {
      var response = await clientRidesRepo.getRides(
        pickLat: pickLat!,
        pickLong: pickLong!,
        dropLat: dropLat!,
        dropLong: dropLong!,
      );
      log("clientGetRides response object type: ${response.runtimeType}");
      log("clientGetRides response.isRight=${response.isRight} response.isLeft=${response.isLeft}");

      if (response.isRight) {
        log("clientGetRides response.right type: ${response.right.runtimeType}");
        final rawMatchedRides = response.right['matchedRides'];
        log(
          "clientGetRides raw matchedRides type: ${rawMatchedRides.runtimeType}",
        );
        final List data = rawMatchedRides is List ? rawMatchedRides : [];
        log("clientGetRides raw matchedRides length: ${data.length}");
        final List<AvailaibleRidesModel> parsedRides = [];

        for (int i = 0; i < data.length; i++) {
          final ride = data[i];
          log("clientGetRides ride[$i] payload: $ride");
          if (ride is! Map) {
            log(
              "clientGetRides ride[$i] skipped invalid payload type: ${ride.runtimeType}",
            );
            continue;
          }
          try {
            final normalizedRide = Map<String, dynamic>.from(ride);
            final parsedRide = AvailaibleRidesModel.fromJson(normalizedRide);
            parsedRides.add(parsedRide);
            log(
              "clientGetRides ride[$i] parse success: rideId=${parsedRide.rideId}",
            );
          } catch (e) {
            log("clientGetRides ride[$i] parse failure: $e");
          }
        }

        log("clientGetRides parsedRides length: ${parsedRides.length}");
        availableRides.assignAll(parsedRides);
        log("clientGetRides availableRides length: ${availableRides.length}");

        if (availableRides.isNotEmpty) {
          requestState.value = RequestState.success;
        } else {
          requestState.value = RequestState.none;
        }
        log("clientGetRides final requestState: ${requestState.value}");
      } else {
        requestState.value = RequestState.failed;
        log("clientGetRides final requestState: ${requestState.value}");
      }
    } catch (e) {
      log("clientGetRides parse/load error: $e");
      requestState.value = RequestState.error;
      log("clientGetRides final requestState: ${requestState.value}");
    }
  }

  Future<void> bookRide({required String rideId}) async {
    requestState.value = RequestState.loading;
    try {
      log("BOOK_RIDE: Starting booking for rideId: $rideId");
      log("BOOK_RIDE: Coordinates - pickup: ($pickLat,$pickLong), dropoff: ($dropLat,$dropLong)");

      final blockingReason = await _getRideRequestBlockReason();
      if (blockingReason != null) {
        log("BOOK_RIDE: blocked by current trip state");
        requestState.value = RequestState.success;
        _showFeedback("Ride unavailable", blockingReason);
        return;
      }

      var response = await clientBookRideRepo.bookRide(
        pickLat: pickLat!,
        pickLong: pickLong!,
        dropLat: dropLat!,
        dropLong: dropLong!,
        rideId: rideId,
      );

      log("BOOK_RIDE: Response type: ${response.runtimeType}");
      log("BOOK_RIDE: Response.isRight: ${response.isRight}");
      if (response.isRight) {
        log("BOOK_RIDE: Response data: ${response.right}");
        final responseData = response.right;
        log("BOOK_RIDE: Response keys: ${responseData.keys.toList()}");
        log("BOOK_RIDE: Response message: ${responseData['message']}");
        if (responseData['request'] != null) {
          log("BOOK_RIDE: Request ID: ${responseData['request']['_id']}");
        }
      }

      if (response.isRight) {
        if (response.right['message'] == null) {
          // Handle Success Join Ride
          log("BOOK_RIDE: Success - navigating to success screen");
          Get.toNamed(
            AppRoutesNames.successCreateRide,
            arguments: {
              "request": response.right,
              "pickPoint": pickPoint,
              "targetPoint": targetPoint,
            },
          );
          sendNotification(
            clientId: sharedPreferences.getString("userId")!,
            rideId: rideId,
            type: NotificationType.requestSent,
            message: "Join request sent to driver",
          );
          _showFeedback("Success", "Request sent successfully");
          
        } else {
          log("BOOK_RIDE: Failed - ${response.right['message']}");
          _showFeedback("Failed", "${response.right['message']}");
        }
        requestState.value = RequestState.success;
      } else {
        log("BOOK_RIDE: Error - ${response.left}");
        _showFeedback("Failed", "${response.left}");
        requestState.value = RequestState.failed;
      }
    } catch (e) {
      log("BOOK_RIDE: Exception - $e");
      requestState.value = RequestState.error;
    }
  }

  void moveToRideLocation({
    required double latitude,
    required double longitude,
  }) {
    if (!_isValidCoordinate(latitude, longitude) ||
        !_isValidCoordinate(pickLat, pickLong)) {
      try {
        Get.snackbar("Route unavailable", "Invalid map coordinates");
      } catch (_) {}
      return;
    }

    if (markers.length < 2) {
      markers.add(
        Marker(
          point: LatLng(latitude, longitude),
          child: Icon(Icons.car_rental, color: AppColors.greenColor, size: 35),
        ),
      );
    } else {
      markers[1] = Marker(
        point: LatLng(latitude, longitude),
        child: Icon(Icons.car_rental, color: AppColors.greenColor, size: 35),
      );
    }

    getRoutes(driverLat: latitude, driverLong: longitude);

    final pickup = LatLng(pickLat!, pickLong!);
    final driver = LatLng(latitude, longitude);
    final samePoint =
        pickup.latitude == driver.latitude &&
        pickup.longitude == driver.longitude;

    if (samePoint) {
      mapController.move(driver, 14);
    } else {
      mapController.fitCamera(
        CameraFit.coordinates(
          forceIntegerZoomLevel: true,
          coordinates: [driver, pickup],
        ),
      );
    }
    update();
  }



  initilaSirvices() {
    mapController = MapController();
    final args = Get.arguments;
    log("availableRides init arguments: type=${args.runtimeType} value=$args");
    if (args is Map) {
      pickLat = _toDouble(args["pickLat"] ?? args["pickupLat"] ?? args["pick_lat"]);
      pickLong = _toDouble(args["pickLong"] ?? args["pickupLong"] ?? args["pick_long"]);
      dropLat = _toDouble(args["dropLat"] ?? args["drop_lat"]);
      dropLong = _toDouble(args["dropLong"] ?? args["drop_long"]);
      pickPoint = args["pick_point"] as String?;
      targetPoint = args["target_point"] as String?;
      log(
        "availableRides parsed args: pick=($pickLat,$pickLong) drop=($dropLat,$dropLong) pickPoint=$pickPoint targetPoint=$targetPoint",
      );
    } else {
      log("availableRides init arguments are not a Map; skipping parse");
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  bool _isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (!lat.isFinite || !lng.isFinite) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  @override
  void onInit() {
    initilaSirvices();
    super.onInit();
  }

  @override
  void onReady() {
    assignMarkers();
    getAvailaibleRides();
    super.onReady();
  }
}
