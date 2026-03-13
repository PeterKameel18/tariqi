import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:developer';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/main.dart';
import 'package:tariqi/client_repo/client_rides_repo.dart';
import 'package:tariqi/models/user_rides_model.dart';
import 'package:tariqi/web_services/dio_config.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/client_repo/cancel_ride_request.dart';

class UserTripsController extends GetxController with WidgetsBindingObserver {
  ClientRidesRepo clientRidesRepo = ClientRidesRepo(dioClient: DioClient());

  CancelRideRequestRepo cancelRideRequestRepo = CancelRideRequestRepo(
    dioClient: DioClient(),
  );

  Rx<RequestState> requestState = RequestState.none.obs;

  RxList<UserRidesModel> userRides = <UserRidesModel>[].obs;

  String screenTitle = "";

  String requestId = "";
  Timer? _refreshTimer;
  bool _isFetchingRides = false;

  bool _isActiveRideStatus(String? status) {
    final normalized = (status ?? '').toLowerCase();
    return normalized == 'accepted' || normalized == 'active';
  }

  UserRidesModel? get primaryActiveRide {
    try {
      return userRides.firstWhere(
        (ride) => _isActiveRideStatus(ride.status),
      );
    } catch (_) {
      return null;
    }
  }

  DateTime _parseRideSortTimestamp(Map<String, dynamic> ride) {
    final candidates = [
      ride['sortTimestamp'],
      ride['finishedAt'],
      ride['cancelledAt'],
      ride['createdAt'],
    ];

    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(candidate);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _rideStatusPriority(Map<String, dynamic> ride) {
    final status = (ride['status'] ?? '').toString().toLowerCase();
    switch (status) {
      case 'finished':
      case 'completed':
      case 'cancelled':
      case 'rejected':
        return 4;
      case 'accepted':
      case 'active':
        return 3;
      case 'pending':
        return 2;
      default:
        return 1;
    }
  }

  bool _shouldMergeRideEntries(
    Map<String, dynamic> existing,
    Map<String, dynamic> candidate,
  ) {
    final existingRequestId = (existing['requestId'] ?? '').toString();
    final candidateRequestId = (candidate['requestId'] ?? '').toString();
    if (existingRequestId.isNotEmpty &&
        candidateRequestId.isNotEmpty &&
        existingRequestId == candidateRequestId) {
      return true;
    }

    final existingRideId = (existing['rideId'] ?? '').toString();
    final candidateRideId = (candidate['rideId'] ?? '').toString();
    if (existingRideId.isEmpty ||
        candidateRideId.isEmpty ||
        existingRideId != candidateRideId) {
      return false;
    }

    // Merge active ride entries that temporarily coexist with a pending/request
    // representation for the same underlying ride while status propagation settles.
    return existingRequestId.isEmpty || candidateRequestId.isEmpty;
  }

  Map<String, dynamic> _selectPreferredRideEntry(
    Map<String, dynamic> current,
    Map<String, dynamic> candidate,
  ) {
    final currentPriority = _rideStatusPriority(current);
    final candidatePriority = _rideStatusPriority(candidate);
    if (candidatePriority != currentPriority) {
      return candidatePriority > currentPriority ? candidate : current;
    }

    final currentTimestamp = _parseRideSortTimestamp(current);
    final candidateTimestamp = _parseRideSortTimestamp(candidate);
    if (candidateTimestamp != currentTimestamp) {
      return candidateTimestamp.isAfter(currentTimestamp) ? candidate : current;
    }

    final currentRequestId = (current['requestId'] ?? '').toString();
    final candidateRequestId = (candidate['requestId'] ?? '').toString();
    if (currentRequestId.isEmpty && candidateRequestId.isNotEmpty) {
      return candidate;
    }

    return current;
  }

  List<Map<String, dynamic>> _dedupeRideEntries(
    List<Map<String, dynamic>> rides,
  ) {
    final deduped = <Map<String, dynamic>>[];

    for (final ride in rides) {
      final existingIndex = deduped.indexWhere(
        (existing) => _shouldMergeRideEntries(existing, ride),
      );

      if (existingIndex == -1) {
        deduped.add(ride);
        continue;
      }

      deduped[existingIndex] = _selectPreferredRideEntry(
        deduped[existingIndex],
        ride,
      );
    }

    return deduped;
  }

  Future<void> getRides({bool showLoading = true}) async {
    if (_isFetchingRides) return;
    _isFetchingRides = true;

    log("GET_RIDES: Starting fetch");
    if (showLoading) {
      userRides.value = [];
      requestState.value = RequestState.loading;
    }

    try {
      var response = await clientRidesRepo.getRides();
      log("GET_RIDES: Response type: ${response.runtimeType}");
      log("GET_RIDES: Response.isRight: ${response.isRight}");

      if (response.isRight) {
        List data = [];
        data = response.right['rides'];
        log("GET_RIDES: Raw rides data length: ${data.length}");

        final sortedData = data
            .whereType<Map>()
            .map((ride) => Map<String, dynamic>.from(ride))
            .toList()
          ..sort((a, b) {
            final timeCompare =
                _parseRideSortTimestamp(b).compareTo(_parseRideSortTimestamp(a));
            if (timeCompare != 0) {
              return timeCompare;
            }

            final aId = (a['requestId'] ?? a['rideId'] ?? '').toString();
            final bId = (b['requestId'] ?? b['rideId'] ?? '').toString();
            return bId.compareTo(aId);
          });

        final dedupedData = _dedupeRideEntries(sortedData);

        for (int i = 0; i < dedupedData.length; i++) {
          final ride = dedupedData[i];
          log("GET_RIDES: Ride[$i] - rideId: ${ride['rideId']}, status: ${ride['status']}, requestId: ${ride['requestId']}");
          log("GET_RIDES: Ride[$i] full data: $ride");
        }

        userRides.value =
            dedupedData.map((ride) => UserRidesModel.fromJson(ride)).toList();
        log("GET_RIDES: Parsed ${userRides.length} rides");
        changeScreenTitle();

        requestState.value = RequestState.success;
      } else {
        log("GET_RIDES: Failed to fetch rides");
        if (showLoading) {
          userRides.value = [];
          changeScreenTitle();
          requestState.value = RequestState.none;
        }
      }
    } finally {
      _isFetchingRides = false;
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      await getRides(showLoading: false);
    });
  }

  void ridesAction({required String status, String? requestId}) {
    switch (status) {
      case "accepted":
      case "active":
        Get.offNamed(AppRoutesNames.paymentScreen);
        break;
      case "pending":
        if (requestId == null || requestId.isEmpty) {
          try { 
        Get.snackbar("Failed", "Missing request id for cancellation"); 
      } catch (e) { 
        log("ridesAction: Snackbar error: $e");
      }
          break;
        }
        cancelRideRequest(requestId: requestId);
        break;
      case "completed":
      case "finished":
        debugPrint("Review");
        break;
      case "cancelled":
      case "rejected":
        debugPrint("Re-Request");
        break;
      default:
        break;
    }
  }

  Future<void> cancelRideRequest({required String requestId}) async {
    log("CANCEL_RIDE: Starting cancel for requestId: $requestId");
    requestState.value = RequestState.loading;
    var response = await cancelRideRequestRepo.cancelRideRequest(
      requestId: requestId,
    );
    log("CANCEL_RIDE: Response type: ${response.runtimeType}");
    log("CANCEL_RIDE: Response data: $response");
    
    final statusCode = response["statusCode"] as int?;
    final data = response["data"];
    log("CANCEL_RIDE: Status code: $statusCode");
    log("CANCEL_RIDE: Response data: $data");
    
    if (statusCode == 200) {
      final message = data is Map ? (data["message"] ?? "Request cancelled successfully") : "Request cancelled successfully";
      log("CANCEL_RIDE: Success - $message");
      try { 
        Get.snackbar("Success", "$message"); 
      } catch (e) { 
        log("CANCEL_RIDE: Snackbar error: $e");
      }
      sharedPreferences.remove("request_id");
      this.requestId = "";
      log("CANCEL_RIDE: Refreshing rides after cancel");
      await getRides();
      requestState.value = RequestState.success;
    } else {
      final message = data is Map ? (data["message"] ?? "Error occurred while processing your request") : "Error occurred while processing your request";
      log("CANCEL_RIDE: Failed - $message");
      try { 
        Get.snackbar("Failed", "$message"); 
      } catch (e) { 
        log("CANCEL_RIDE: Snackbar error: $e");
      }
      requestState.value = RequestState.none;
    }
  }

  String userRideAction({required String status}) {
    switch (status) {
      case "accepted":
      case "active":
        return "CheckOut";
      case "pending":
        return "Cancel";
      case "completed":
      case "finished":
        return "Review";
      case "cancelled":
      case "rejected":
        return "Re-Request";
      default:
        return "";
    }
  }

  void goToChatScreen({required String rideId}) {
    Get.toNamed(AppRoutesNames.chatScreen, arguments: {"rideId": rideId});
  }

  void openActiveRide(UserRidesModel ride) {
    Get.toNamed(
      AppRoutesNames.trackRequestScreen,
      arguments: {"userRidesModel": ride},
    );
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
    
    sharedPreferences.setBool('_didAutoRecoverTrip', true);
  }

  @override
  void onInit() {
    WidgetsBinding.instance.addObserver(this);
    initialServices();
    super.onInit();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      getRides(showLoading: false);
    }
  }

  @override
  void onReady() {
    getRides();
    _startAutoRefresh();
    super.onReady();
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
