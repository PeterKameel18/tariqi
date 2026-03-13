import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/controller/driver/driver_active_ride_controller.dart';

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
    'loadRideData refreshes onboard passengers immediately after accept without screen re-entry',
    () async {
      final fakeDriverService = FakeDriverService(
        initialRideId: 'ride-123',
        rideDataResponse: {
          'route': [
            {'lat': 30.0444, 'lng': 31.2357},
            {'lat': 30.0107, 'lng': 30.9728},
          ],
          'passengers': <Map<String, dynamic>>[],
        },
      );

      final controller = DriverActiveRideController(
        driverService: fakeDriverService,
        enableLocationBootstrap: false,
      );

      controller.onInit();
      await controller.loadRideData();

      expect(controller.passengers, isEmpty);
      expect(controller.requestState.value, RequestState.online);

      fakeDriverService.rideDataResponse = {
        'route': [
          {'lat': 30.0444, 'lng': 31.2357},
          {'lat': 30.0107, 'lng': 30.9728},
        ],
        'passengers': [
          {
            'requestId': 'request-456',
            'name': 'Sara Ali',
            'rating': 4.8,
            'price': 45,
            'pickedUp': false,
            'droppedOff': false,
            'pickup': 'Tahrir Square',
            'dropoff': 'Sheikh Zayed',
            'pickupLocation': {'lat': 30.0444, 'lng': 31.2357},
            'dropoffLocation': {'lat': 30.0107, 'lng': 30.9728},
          },
        ],
      };

      await controller.loadRideData();

      expect(fakeDriverService.getRideDataCalls, 2);
      expect(controller.passengers, hasLength(1));
      expect(controller.passengers.single['id'], 'request-456');
      expect(controller.passengers.single['name'], 'Sara Ali');
      expect(controller.passengers.single['pickup'], 'Tahrir Square');
      expect(controller.passengers.single['dropoff'], 'Sheikh Zayed');
      expect(controller.requestState.value, RequestState.online);
      expect(
        fakeDriverService.debugSavedPassengers('ride-123'),
        isNotNull,
      );
      expect(
        fakeDriverService.debugSavedPassengers('ride-123'),
        hasLength(1),
      );

      controller.onClose();
    },
  );
}
