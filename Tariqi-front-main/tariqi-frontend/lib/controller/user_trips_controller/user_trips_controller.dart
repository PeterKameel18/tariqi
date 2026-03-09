import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'dart:developer';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/main.dart';
import 'package:tariqi/client_repo/client_rides_repo.dart';
import 'package:tariqi/models/user_rides_model.dart';
import 'package:tariqi/web_services/dio_config.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/client_repo/cancel_ride_request.dart';

class UserTripsController extends GetxController {
  ClientRidesRepo clientRidesRepo = ClientRidesRepo(dioClient: DioClient());

  CancelRideRequestRepo cancelRideRequestRepo = CancelRideRequestRepo(
    dioClient: DioClient(),
  );

  Rx<RequestState> requestState = RequestState.none.obs;

  RxList<UserRidesModel> userRides = <UserRidesModel>[].obs;

  String screenTitle = "";

  String requestId = "";

  Future<void> getRides() async {
    userRides.value = [];
    requestState.value = RequestState.loading;
    var response = await clientRidesRepo.getRides();
    if (response.isRight) {
      List data = [];
      data = response.right['rides'];

      userRides.value =
          data.map((ride) => UserRidesModel.fromJson(ride)).toList();
      changeScreenTitle();

      requestState.value = RequestState.success;
    } else {
      userRides.value = [];
      changeScreenTitle();
      requestState.value = RequestState.none;
    }
  }

  void ridesAction({required String status}) {
    switch (status) {
      case "accepted":
        Get.offNamed(AppRoutesNames.paymentScreen);
      // Goto Check Out
      case "pending":
        cancelRideRequest();
      // Cancel Request
      case "completed":
        debugPrint("Review");
      // Goto Review
      case "cancelled":
        debugPrint("Re-Request");
      // Goto Re-Request
      default:
        break;
    }
  }

  Future<void> cancelRideRequest() async {
    requestState.value = RequestState.loading;
    var response = await cancelRideRequestRepo.cancelRideRequest(
      requestId: requestId,
    );
    if (response is Map) {
      Get.snackbar("Success", response['message']);
      sharedPreferences.remove("request_id");
      requestId = "";
      await getRides();
      requestState.value = RequestState.success;
    } else {
      Get.snackbar("Failed", "Error Ocured While Proccessing Your Request");
      requestState.value = RequestState.none;
    }
  }

  String userRideAction({required String status}) {
    switch (status) {
      case "accepted":
        return "CheckOut";
      case "pending":
        return "Cancel";
      case "completed":
        return "Review";
      case "cancelled":
        return "Re-Request";
      default:
        return "";
    }
  }

  void goToChatScreen({required String rideId}) {
    Get.toNamed(AppRoutesNames.chatScreen, arguments: {"rideId": rideId});
  }

  void changeScreenTitle() {
    if (userRides.isNotEmpty) {
      screenTitle = "Your Trips";
    } else {
      screenTitle = "Static Trips";
    }

    update();
  }

  initialServices() {
    requestId = sharedPreferences.getString("request_id") ?? "";

    sharedPreferences.getString("request_id") != null
        ? log("Request Id is ${sharedPreferences.getString("request_id")}")
        : log("Request Id is empty");
  }

  @override
  void onInit() {
    initialServices();
    super.onInit();
  }

  @override
  void onReady() {
    getRides();
    super.onReady();
  }
}
