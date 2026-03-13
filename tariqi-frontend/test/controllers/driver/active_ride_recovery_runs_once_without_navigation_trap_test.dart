import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tariqi/controller/driver/driver_home_controller.dart';

import '../../helpers/ride_test_helpers.dart';

class TestDriverHomeController extends DriverHomeController {
  TestDriverHomeController({
    required this.fakeDriverService,
  }) : super(
         driverService: fakeDriverService,
         enableLocationBootstrap: false,
       );

  final FakeDriverService fakeDriverService;

  int navigateCalls = 0;
  String? lastNavigatedRideId;

  @override
  Future<void> checkForActiveRide() async {
    final hasRide = await fakeDriverService.hasActiveRide();
    if (hasRide && fakeDriverService.currentRideId != null) {
      hasActiveRide.value = true;
      activeRideId.value = fakeDriverService.currentRideId!;
    } else {
      hasActiveRide.value = false;
      activeRideId.value = '';
    }
  }

  @override
  void navigateToActiveRide(String? rideId) {
    navigateCalls += 1;
    lastNavigatedRideId = rideId;
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Get.testMode = true;
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  test('startup recovery redirects once when active ride exists', () async {
    final fakeDriverService = FakeDriverService(
      activeRideExists: true,
      initialRideId: 'ride-123',
    );
    final controller = TestDriverHomeController(
      fakeDriverService: fakeDriverService,
    );

    controller.onInit();
    await controller.recoverActiveRideOnStartupForTest();
    await controller.recoverActiveRideOnStartupForTest();

    expect(fakeDriverService.hasActiveRideCalls, 1);
    expect(fakeDriverService.startGlobalRequestPollingCalls, 1);
    expect(controller.navigateCalls, 1);
    expect(controller.lastNavigatedRideId, 'ride-123');
  });

  test('suppression skips forced re-entry after intentional back navigation', () async {
    final fakeDriverService = FakeDriverService(
      activeRideExists: true,
      initialRideId: 'ride-123',
    );
    fakeDriverService.suppressNextActiveRideRecovery(
      source: 'driver_active_ride_back',
    );

    final controller = TestDriverHomeController(
      fakeDriverService: fakeDriverService,
    );

    controller.onInit();
    await controller.recoverActiveRideOnStartupForTest();

    expect(fakeDriverService.hasActiveRideCalls, 0);
    expect(fakeDriverService.startGlobalRequestPollingCalls, 0);
    expect(controller.navigateCalls, 0);
    expect(controller.hasActiveRide.value, isFalse);
    expect(controller.activeRideId.value, isEmpty);
  });
}
