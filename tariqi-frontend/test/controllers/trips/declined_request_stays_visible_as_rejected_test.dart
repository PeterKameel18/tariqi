import 'package:either_dart/either.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/controller/user_trips_controller/user_trips_controller.dart';
import 'package:tariqi/models/user_rides_model.dart';
import 'package:tariqi/view/trips_screen/widgets/user_ride_card.dart';

import '../../helpers/auth_test_helpers.dart';
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

  test('declined request remains present in trips data with rejected status', () async {
    final controller = UserTripsController();
    controller.clientRidesRepo = FakeClientRidesRepo(
      onGetRides: () async => Right({
        'rides': [
          {
            'rideId': 'ride-001',
            'requestId': 'request-001',
            'availableSeats': 3,
            'createdAt': '2026-03-12T12:36:00.776Z',
            'status': 'rejected',
            'driver': {
              'firstName': 'Ahmed',
              'lastName': 'Hassan',
              'carDetails': {
                'make': 'Toyota',
                'model': 'Corolla',
                'licensePlate': 'ABC-1234',
              },
            },
          },
        ],
      }),
    );

    await controller.getRides(showLoading: false);

    expect(controller.requestState.value, RequestState.success);
    expect(controller.userRides, hasLength(1));
    expect(controller.userRides.single.requestId, 'request-001');
    expect(controller.userRides.single.status, 'rejected');
  });

  test('accepted ride payload dedupes pending and active representations into one item', () async {
    final controller = UserTripsController();
    controller.clientRidesRepo = FakeClientRidesRepo(
      onGetRides: () async => Right({
        'rides': [
          {
            'rideId': 'ride-accept-001',
            'requestId': 'request-accept-001',
            'availableSeats': 2,
            'createdAt': '2026-03-13T10:00:00.000Z',
            'sortTimestamp': '2026-03-13T10:00:00.000Z',
            'status': 'pending',
            'driver': {
              'firstName': 'Ahmed',
              'lastName': 'Hassan',
            },
          },
          {
            'rideId': 'ride-accept-001',
            'requestId': 'request-accept-001',
            'availableSeats': 2,
            'createdAt': '2026-03-13T10:00:00.000Z',
            'sortTimestamp': '2026-03-13T10:00:03.000Z',
            'status': 'active',
            'driver': {
              'firstName': 'Ahmed',
              'lastName': 'Hassan',
            },
          },
        ],
      }),
    );

    await controller.getRides(showLoading: false);

    expect(controller.requestState.value, RequestState.success);
    expect(controller.userRides, hasLength(1));
    expect(controller.userRides.single.requestId, 'request-accept-001');
    expect(controller.userRides.single.rideId, 'ride-accept-001');
    expect(controller.userRides.single.status, 'active');
  });

  testWidgets('rejected trip card shows REJECTED label and hides action footer', (
    tester,
  ) async {
    final controller = UserTripsController();
    final rejectedRide = UserRidesModel(
      rideId: 'ride-001',
      requestId: 'request-001',
      createdAt: '2026-03-12T12:36:00.776Z',
      availableSeats: 3,
      status: 'rejected',
      driver: Driver(
        firstName: 'Ahmed',
        lastName: 'Hassan',
      ),
    );

    await pumpGetApp(
      tester,
      home: Material(
        child: userRideCard(
          controller: controller,
          userRidesModel: rejectedRide,
        ),
      ),
    );

    expect(find.text('REJECTED'), findsOneWidget);
    expect(find.text('Re-Request'), findsNothing);
    expect(find.text('Track Ride'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  });
}
