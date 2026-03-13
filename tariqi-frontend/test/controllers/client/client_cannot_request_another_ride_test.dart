import 'package:either_dart/either.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tariqi/controller/available_rides_controller/available_rides_controller.dart';

import '../../helpers/ride_test_helpers.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Get.testMode = true;
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  test(
    'bookRide is blocked when client already has an active or pending trip state',
    () async {
      final fakeTripsRepo = FakeClientRidesRepo(
        onGetRides: () async => Right({
          'rides': [
            {
              'rideId': 'ride-existing',
              'requestId': 'request-existing',
              'status': 'accepted',
            },
          ],
        }),
      );
      final fakeBookRideRepo = FakeClientBookRideRepo();

      final controller = AvailableRidesController(
        clientTripsRepo: fakeTripsRepo,
        clientBookRideRepo: fakeBookRideRepo,
        feedbackHandler: (_, __) {},
      )
        ..pickLat = 30.0444
        ..pickLong = 31.2357
        ..dropLat = 30.0131
        ..dropLong = 31.2089;

      await controller.bookRide(rideId: 'ride-new');

      expect(fakeTripsRepo.getRidesCalls, 1);
      expect(fakeBookRideRepo.bookRideCalls, 0);
    },
  );
}
