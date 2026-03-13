import 'package:either_dart/either.dart';
import 'package:tariqi/client_repo/availaible_rides_repo.dart';
import 'package:tariqi/client_repo/client_rides_repo.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/services/driver_service.dart';
import 'package:tariqi/web_services/dio_config.dart';

class FakeClientRidesRepo extends ClientRidesRepo {
  FakeClientRidesRepo({
    this.onGetRides,
  }) : super(dioClient: DioClient());

  final Future<Either<RequestState, Map<String, dynamic>>> Function()? onGetRides;
  int getRidesCalls = 0;

  @override
  Future<Either<RequestState, Map<String, dynamic>>> getRides() async {
    getRidesCalls += 1;
    if (onGetRides != null) {
      return onGetRides!();
    }

    return Right({'rides': <Map<String, dynamic>>[]});
  }
}

class FakeDriverService extends DriverService {
  FakeDriverService({
    this.activeRideExists = false,
    this.rideDataResponse,
    this.dropoffPassengerResult = true,
    String? initialRideId,
    List<Map<String, dynamic>>? initialSavedPassengers,
  }) {
    currentRideId = initialRideId;
    if (initialRideId != null && initialSavedPassengers != null) {
      _savedPassengers[initialRideId] = List<Map<String, dynamic>>.from(
        initialSavedPassengers,
      );
    }
  }

  bool activeRideExists;
  Map<String, dynamic>? rideDataResponse;
  bool dropoffPassengerResult;

  int hasActiveRideCalls = 0;
  int getRideDataCalls = 0;
  int startGlobalRequestPollingCalls = 0;
  int dropoffPassengerCalls = 0;

  final Map<String, List<Map<String, dynamic>>> _savedPassengers = {};

  @override
  Future<bool> hasActiveRide() async {
    hasActiveRideCalls += 1;
    return activeRideExists;
  }

  @override
  Future<Map<String, dynamic>?> getRideData(String rideId) async {
    getRideDataCalls += 1;
    return rideDataResponse;
  }

  @override
  void startGlobalRequestPolling() {
    startGlobalRequestPollingCalls += 1;
  }

  @override
  Future<bool> dropoffPassenger(String requestId) async {
    dropoffPassengerCalls += 1;
    return dropoffPassengerResult;
  }

  @override
  Future<void> savePassengers(
    String rideId,
    List<Map<String, dynamic>> passengers,
  ) async {
    _savedPassengers[rideId] = List<Map<String, dynamic>>.from(passengers);
  }

  @override
  Future<List<Map<String, dynamic>>?> getSavedPassengers(String rideId) async {
    final savedPassengers = _savedPassengers[rideId];
    return savedPassengers == null
        ? null
        : List<Map<String, dynamic>>.from(savedPassengers);
  }

  List<Map<String, dynamic>>? debugSavedPassengers(String rideId) {
    final savedPassengers = _savedPassengers[rideId];
    return savedPassengers == null
        ? null
        : List<Map<String, dynamic>>.from(savedPassengers);
  }
}

class FakeClientBookRideRepo extends ClientBookRideRepo {
  FakeClientBookRideRepo({
    this.onBookRide,
  }) : super(dioClient: DioClient());

  final Future<Either<RequestState, Map<String, dynamic>>> Function()? onBookRide;
  int bookRideCalls = 0;

  @override
  Future<Either<RequestState, Map<String, dynamic>>> bookRide({
    required double pickLat,
    required double pickLong,
    required double dropLat,
    required double dropLong,
    required String rideId,
  }) async {
    bookRideCalls += 1;
    if (onBookRide != null) {
      return onBookRide!();
    }

    return Right(<String, dynamic>{});
  }
}
