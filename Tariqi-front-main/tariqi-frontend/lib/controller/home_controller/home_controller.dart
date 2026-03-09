import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/colors/app_colors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/main.dart';
import 'package:tariqi/client_repo/client_info_repo.dart';
import 'package:tariqi/client_repo/location_repo.dart';
import 'package:tariqi/models/client_info_model.dart';

class HomeController extends GetxController {
  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  ClientInfoRepo clientInfoRepo = ClientInfoRepo(dioClient: Get.find());
  ClientLocationCordinatesRepo clientLocationRepo =
      ClientLocationCordinatesRepo(dioClient: Get.find());
  ClientLocationNameRepo clientLocationNameRepo = ClientLocationNameRepo(
    dioClient: Get.find(),
  );

  late MapController mapController;
  late TextEditingController pickPointController;
  Rx<RequestState> requestState = RequestState.none.obs;
  RxBool isLocationDisabled = true.obs;
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
  RxList<Marker> markers = RxList<Marker>([]);

  List<ClientInfoModel> clientInfo = [];

  RxBool selectedRide = true.obs;

  Future<LatLng?> getClientLocation({required String location}) async {
    var response = await clientLocationRepo.getClientLocationCordinates(
      location: location,
    );
    if (response != null) {
      markers.add(
        Marker(
          point: LatLng(response.latitude, response.longitude),
          child: Icon(Icons.location_on, color: AppColors.blueColor, size: 30),
        ),
      );
      mapController.move(LatLng(response.latitude, response.longitude), 12);
      requestState.value = RequestState.success;

      return LatLng(response.latitude, response.longitude);
    } else {
      Get.snackbar("Failed", "Error Ocured While Proccessing Your Location");
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
      pickPointController.text = response;
      requestState.value = RequestState.success;
    } else {
      Get.snackbar("Failed", "Error Ocured While Proccessing Your Location");
      requestState.value = RequestState.none;
    }
    return response;
  }

  Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // تأكد إن الـ GPS شغال
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    // تحقق من صلاحية الوصول للموقع
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    isLocationDisabled.value = false;
    // هيرجعلك الموقع الحالي
    return await Geolocator.getCurrentPosition();
  }

  void getUserLocation() async {
    try {
      requestState.value = RequestState.loading;
      userPosition = await determinePosition();

      await getLocationName(
        lat: userPosition.latitude,
        long: userPosition.longitude,
      );

      assignMarkers(
        point: LatLng(userPosition.latitude, userPosition.longitude),
      );

      requestState.value = RequestState.success;
    } catch (e) {
      return Future.error('Failed to get user location: $e');
    }
  }

  void checkLocationPremission() async {
    requestState.value = RequestState.loading;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      getUserLocation();
      isLocationDisabled.value = false;
    } else {
      requestState.value = RequestState.none;
      isLocationDisabled.value = true;
    }
  }

  void selectRideType() {
    selectedRide.value = !selectedRide.value;
  }

  void assignMarkers({required LatLng point}) async {
    requestState.value = RequestState.loading;
    await getLocationName(lat: point.latitude, long: point.longitude);
    mapController.move(LatLng(point.latitude, point.longitude), 15);

    if (markers.isNotEmpty) {
      markers.replaceRange(0, markers.length, [
        Marker(
          point: LatLng(point.latitude, point.longitude),
          child: Icon(Icons.location_on, color: AppColors.blueColor, size: 30),
        ),
      ]);
    } else {
      markers.add(
        Marker(
          point: LatLng(point.latitude, point.longitude),
          child: Icon(Icons.location_on, color: AppColors.blueColor, size: 30),
        ),
      );
    }

    userPosition = Position(
      longitude: point.longitude,
      latitude: point.latitude,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );

    markers.refresh();

    requestState.value = RequestState.success;
  }

  void goToCreateRideScreen() {
    Get.offNamed(
      AppRoutesNames.createRideScreen,
      arguments: {
        "markers": markers,
        "pick_point": pickPointController.text,
        "position": userPosition,
      },
    );
  }

  Future getUserData() async {
    requestState.value = RequestState.loading;

    try {
      var response = await clientInfoRepo.loadProfile();

      if (response is RequestState) {
        requestState.value = response;
      } else if (response is Map) {
        List data = [];

        data.add(response['user']);

        clientInfo = data.map((e) => ClientInfoModel.fromJson(e)).toList();

        requestState.value = RequestState.success;
      }
    } catch (e) {
      requestState.value = RequestState.error;
    }
  }

  void drawerNavigationFunc({required String title}) {
    switch (title) {
      case "trips":
        Get.offNamed(AppRoutesNames.userTripsScreen);
        break;

      case "payment":
        // handle payment
        debugPrint("Payment");
        break;

      case "logout":
        // handle logout
        sharedPreferences.clear();
        Get.offNamed(AppRoutesNames.loginScreen);
        break;

      case "notifications":
        Get.offNamed(AppRoutesNames.notificationScreen);
        break;

      default:
        break;
    }
  }

  void initControllers() {
    mapController = MapController();
    pickPointController = TextEditingController(
      text: "Please Wait To Get Your Location",
    );
  }

  void disposeController() {
    mapController.dispose();
    pickPointController.dispose();
  }

  @override
  void onInit() {
    initControllers();
    checkLocationPremission();
    getUserData();
    super.onInit();
  }

  @override
  void onClose() {
    disposeController();
    super.onClose();
  }
}
