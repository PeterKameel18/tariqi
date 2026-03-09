import 'package:flutter/material.dart';
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
import 'package:tariqi/client_repo/get_routes_repo.dart';
import 'package:tariqi/models/availaible_rides_model.dart';

class AvailableRidesController extends GetxController {
  late MapController mapController;
  double? pickLat;
  double? pickLong;
  double? dropLat;
  double? dropLong;
  String? pickPoint;
  String? targetPoint;
  List<Marker> markers = [];
  Rx<RequestState> requestState = RequestState.none.obs;
  GetRoutesRepo getRoutesRepo = GetRoutesRepo(dioClient: Get.find());
  ClientAvailableRidesRepo clientRidesRepo = ClientAvailableRidesRepo(
    dioClient: Get.find(),
  );
  ClientBookRideRepo clientBookRideRepo = ClientBookRideRepo(
    dioClient: Get.find(),
  );
  List<AvailaibleRidesModel> availableRides = [];
  RxList<LatLng> routes = RxList<LatLng>([]);

  void assignMarkers() {
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
    requestState.value = RequestState.loading;
    try {
      var response = await getRoutesRepo.getRoutes(
        lat1: pickLat!,
        long1: pickLong!,
        lat2: driverLat,
        long2: driverLong,
      );

      if (response.isNotEmpty) {
        routes.value = response.map((e) => LatLng(e[1], e[0])).toList();
        requestState.value = RequestState.success;
      } else {
        routes.value = [];
        requestState.value = RequestState.none;
      }
    } catch (e) {
      Get.snackbar("Failed", "Error getting routes $e");
    }
  }

  getAvailaibleRides() async {
    requestState.value = RequestState.loading;
    try {
      var response = await clientRidesRepo.getRides(
        pickLat: pickLat!,
        pickLong: pickLong!,
        dropLat: dropLat!,
        dropLong: dropLong!,
      );

      if (response.isRight) {
        List data = [];
        data = response.right['matchedRides'];

        availableRides =
            data.map((ride) => AvailaibleRidesModel.fromJson(ride)).toList();

        if (availableRides.isNotEmpty) {
          requestState.value = RequestState.success;
        } else {
          requestState.value = RequestState.none;
        }
      } else {
        requestState.value = RequestState.failed;
      }
    } catch (e) {
      requestState.value = RequestState.error;
    }
  }

  Future<void> bookRide({required String rideId}) async {
    requestState.value = RequestState.loading;
    try {
      var response = await clientBookRideRepo.bookRide(
        pickLat: pickLat!,
        pickLong: pickLong!,
        dropLat: dropLat!,
        dropLong: dropLong!,
        rideId: rideId,
      );

      if (response.isRight) {
        if (response.right['message'] == null) {
          // Handle Success Join Ride
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
          Get.snackbar("Success", "Request sent successfully");
          
        } else {
          Get.snackbar("Failed", "${response.right['message']}");
        }
        requestState.value = RequestState.success;
      } else {
        Get.snackbar("Failed", "${response.left}");
        requestState.value = RequestState.failed;
      }
    } catch (e) {
      requestState.value = RequestState.error;
    }
  }

  void moveToRideLocation({
    required double latitude,
    required double longitude,
  }) {
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

    mapController.fitCamera(
      CameraFit.coordinates(
        forceIntegerZoomLevel: true,
        coordinates: [LatLng(latitude, longitude), LatLng(pickLat!, pickLong!)],
      ),
    );
    update();
  }



  initilaSirvices() {
    mapController = MapController();
    pickLat = Get.arguments["pickLat"];
    pickLong = Get.arguments["pickLong"];
    dropLat = Get.arguments["dropLat"];
    dropLong = Get.arguments["dropLong"];
    pickPoint = Get.arguments["pick_point"];
    targetPoint = Get.arguments["target_point"];
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
