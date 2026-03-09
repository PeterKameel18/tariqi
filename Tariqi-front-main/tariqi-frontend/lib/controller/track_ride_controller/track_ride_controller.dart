import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:tariqi/client_repo/get_routes_repo.dart';
import 'package:tariqi/models/user_rides_model.dart';

class TrackRideController extends GetxController {
  Rx<RequestState> requestState = RequestState.loading.obs;
  late MapController mapController;

  List<Routes> route = [];

  RxList<LatLng> routes = RxList<LatLng>([]);

  RxList<Marker> markers = RxList<Marker>([]);

  GetRoutesRepo getRoutesRepo = GetRoutesRepo(dioClient: Get.find());

  RxDouble distance = 0.0.obs;

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

  void assignMarkers({required LatLng point}) async {
    requestState.value = RequestState.loading;
    markers.add(
      Marker(
        point: LatLng(point.latitude, point.longitude),
        child: Icon(Icons.location_on, color: AppColors.blueColor, size: 30),
      ),
    );
    markers.refresh();
    mapController.fitCamera(
      CameraFit.coordinates(
        padding: EdgeInsets.all(ScreenSize.screenWidth! * 0.1),
        coordinates: [
          LatLng(point.latitude, point.longitude),
          LatLng(point.latitude, point.longitude),
        ],
      ),
    );

    requestState.value = RequestState.success;
  }

  initialMapService() {
    if (route.isNotEmpty &&
        route.every((e) => e.lat != null && e.lng != null)) {
      List<LatLng> points = [];
      for (var element in route) {
        points.add(LatLng(element.lat!, element.lng!));
      }
      markers.addAll(
        points.asMap().entries.map((entry) {
          int idx = entry.key;
          LatLng e = entry.value;
          return Marker(
            point: e,
            child: Icon(
              idx == 0
                  ? Icons.location_on
                  : Icons.directions_car, // First marker: location, second: car
              color: AppColors.blueColor,
              size: 30,
            ),
          );
        }),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapController.fitCamera(
          CameraFit.coordinates(
            padding: EdgeInsets.all(ScreenSize.screenWidth! * 0.1),
            coordinates: points,
          ),
        );
      });

      getRoutes(
        pickLat: points.first.latitude,
        pickLong: points.first.longitude,
        dropLat: points.last.latitude,
        dropLong: points.last.longitude,
      );
    }
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
      var response = await getRoutesRepo.getRoutes(
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
      Get.snackbar("Failed", "Error getting routes $e");
    }

    update();
  }

  startTracking() {
    positionStream = Geolocator.getPositionStream().listen((position) {
      route.last = Routes(lat: position.latitude, lng: position.longitude);
      markers.replaceRange(1, markers.length, [
        Marker(
          point: LatLng(position.latitude, position.longitude),
          child: Icon(
            Icons.directions_car,
            color: AppColors.blueColor,
            size: 30,
          ),
        ),
      ]);

      markers.refresh();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapController.fitCamera(
          CameraFit.coordinates(
            maxZoom: 16,
            padding: EdgeInsets.all(ScreenSize.screenWidth! * 0.1),
            coordinates: route.map((e) => LatLng(e.lat!, e.lng!)).toList(),
          ),
        );
      });

      getRoutes(
        pickLat: route.first.lat!,
        pickLong: route.first.lng!,
        dropLat: route.last.lat!,
        dropLong: route.last.lng!,
      );

      distance.value = Geolocator.distanceBetween(
        route.first.lat!,
        route.first.lng!,
        route.last.lat!,
        route.last.lng!,
      );
    });
  }

  initialServices() {
    markers.clear();
    if (Get.arguments != null) {
      route = Get.arguments['userRidesModel'].route!;
    } else {
      route = [];
    }

    initialMapService();
    startTracking();
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
    positionStream?.cancel();
    super.onClose();
  }
}
