import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/client_repo/get_routes_repo.dart';
import 'package:tariqi/client_repo/location_repo.dart';

class CreateRideController extends GetxController {
  ClientLocationNameRepo clientLocationNameRepo = ClientLocationNameRepo(
    dioClient: Get.find(),
  );
  ClientLocationCordinatesRepo clientLocationCordinatesRepo =
      ClientLocationCordinatesRepo(dioClient: Get.find());
  GetRoutesRepo getRoutesRepo = GetRoutesRepo(dioClient: Get.find());
  late MapController mapController;
  List<Marker> markers = [];
  late TextEditingController pickPointController;
  late TextEditingController targetPointController;
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  Rx<RequestState> requestState = RequestState.none.obs;
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

  double? dropLat;
  double? dropLong;

  RxList<LatLng> routes = RxList<LatLng>([]);

  Future<LatLng?> getTargetLocation({required String location}) async {
    try {
      requestState.value = RequestState.loading;
      final response = await clientLocationCordinatesRepo
          .getClientLocationCordinates(location: location);
      if (response != null) {
        final geometry = response;
        final lat = geometry.latitude;
        final lng = geometry.longitude;

        dropLat = lat;
        dropLong = lng;

        if (markers.length < 2) {
          markers.add(
            Marker(
              point: LatLng(lat, lng),
              child: Icon(
                Icons.location_on,
                color: AppColors.blueColor,
                size: 30,
              ),
            ),
          );
        } else {
          markers[1] = Marker(
            point: LatLng(lat, lng),
            child: Icon(
              Icons.location_on,
              color: AppColors.blueColor,
              size: 30,
            ),
          );
        }

        mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: [
              LatLng(userPosition.latitude, userPosition.longitude),
              LatLng(lat, lng),
            ],
          ),
        );
        requestState.value = RequestState.success;

        return LatLng(lat, lng);
      } else {
        requestState.value = RequestState.failed;
      }
    } catch (e) {
      requestState.value = RequestState.error;
    }
    return null;
  }

  Future getLocationName({required double lat, required double long}) async {
    requestState.value = RequestState.loading;
    var response = await clientLocationNameRepo.getClientLocationName(
      lat: lat,
      long: long,
    );

    if (response != null) {
      targetPointController.text = response;
      requestState.value = RequestState.success;
    } else {
      Get.snackbar("Failed", "Error Ocured While Proccessing Your Location");
      requestState.value = RequestState.none;
    }
    return response;
  }

  void assignMarkers({required LatLng point}) async {
    targetPointController.text = await getLocationName(
      lat: point.latitude,
      long: point.longitude,
    );

    dropLat = point.latitude;
    dropLong = point.longitude;

    if (markers.length < 2 && markers.isNotEmpty) {
      markers.add(
        Marker(
          point: LatLng(point.latitude, point.longitude),
          child: Icon(Icons.location_on, color: AppColors.blueColor, size: 30),
        ),
      );
    } else {
      markers[1] = Marker(
        point: LatLng(point.latitude, point.longitude),
        child: Icon(Icons.location_on, color: AppColors.blueColor, size: 30),
      );
    }

    await getRoutes(
      // starts point
      pickLat: markers[0].point.latitude,
      pickLong: markers[0].point.longitude,

      // ends point
      dropLat: markers[1].point.latitude,
      dropLong: markers[1].point.longitude,
    );

    mapController.fitCamera(
      CameraFit.coordinates(
        forceIntegerZoomLevel: true,
        padding: EdgeInsets.symmetric(horizontal: ScreenSize.screenWidth! * 0.1),
        coordinates: [
          LatLng(markers[0].point.latitude, markers[0].point.longitude),
          LatLng(markers[1].point.latitude, markers[1].point.longitude),
        ],
      ),
    );

    userPosition = Position(
      longitude: markers[0].point.longitude,
      latitude: markers[0].point.latitude,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );

    update();
  }

  void initialServices() async {
    mapController = MapController();
    pickPointController = TextEditingController();
    targetPointController = TextEditingController();
    if (Get.arguments["markers"] != null) {
      markers = Get.arguments["markers"];
      userPosition = Get.arguments['position'];

      if (Get.arguments["pick_point"] == "" ||
          Get.arguments["pick_point"] == null) {
        pickPointController.text = await getLocationName(
          lat: userPosition.latitude,
          long: userPosition.longitude,
        );
      } else {
        pickPointController.text = Get.arguments["pick_point"];
      }
    } else {
      markers = [];
    }

    update();
  }

  void createRide() {
    if (formKey.currentState!.validate()) {
      Get.toNamed(
        AppRoutesNames.availableRides,
        arguments: {
          "pick_point": pickPointController.text,
          "target_point": targetPointController.text,
          "pickLat": userPosition.latitude,
          "pickLong": userPosition.longitude,
          "dropLat": dropLat,
          "dropLong": dropLong,
        },
      );
    }
  }

  Future<void> getRoutes({
    required double pickLat,
    required double pickLong,
    required double dropLat,
    required double dropLong,
  }) async {
    requestState.value = RequestState.loading;
    try {
      routes.value = [];
      var response = await getRoutesRepo.getRoutes(
        lat1: pickLat,
        long1: pickLong,
        lat2: dropLat,
        long2: dropLong,
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

  void disposeActions() {
    pickPointController.dispose();
    targetPointController.dispose();
    mapController.dispose();
  }

  @override
  void onInit() {
    initialServices();
    super.onInit();
  }
}
