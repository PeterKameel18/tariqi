import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tariqi/const/class/request_state.dart';
import 'package:tariqi/const/class/screen_size.dart';
import 'package:tariqi/const/routes/routes_names.dart';
import 'package:tariqi/controller/available_rides_controller/available_rides_controller.dart';
import 'package:tariqi/controller/driver/driver_active_ride_controller.dart';
import 'package:tariqi/controller/track_ride_controller/track_ride_controller.dart';
import 'package:tariqi/controller/user_trips_controller/user_trips_controller.dart';
import 'package:tariqi/models/availaible_rides_model.dart';
import 'package:tariqi/models/user_rides_model.dart';
import 'package:tariqi/view/available_rides_screen/available_rides.dart';
import 'package:tariqi/view/track_ride_screen/track_ride_screen.dart';
import 'package:tariqi/view/trips_screen/user_trips_screen.dart';
import 'package:tariqi/web_services/dio_config.dart';
import 'package:tariqi/main.dart' as app;

import '../test/helpers/ride_test_helpers.dart';
import 'test_helpers.dart';

class HappyPathState {
  final String rideId = 'ride-12345678';
  final String requestId = 'request-12345678';
  final String driverName = 'Ahmed Hassan';
  final String pickupLabel = 'Tahrir Square';
  final String dropoffLabel = 'Sheikh Zayed';
  bool requestSent = false;
  bool accepted = false;
}

class HappyPathAvailableRidesController extends AvailableRidesController {
  HappyPathAvailableRidesController({
    required this.state,
    required this.userTripsController,
  });

  final HappyPathState state;
  final UserTripsController userTripsController;

  @override
  void onInit() {
    mapController = MapController();
    pickLat = 30.0444;
    pickLong = 31.2357;
    dropLat = 30.0107;
    dropLong = 30.9728;
    pickPoint = state.pickupLabel;
    targetPoint = state.dropoffLabel;
    requestState.value = RequestState.success;
    availableRides.assignAll([
      AvailaibleRidesModel(
        rideId: state.rideId,
        availableSeats: 3,
        estimatedPrice: 45,
        driverRoute: [
          OptimizedRoute(lat: 30.0444, lng: 31.2357),
          OptimizedRoute(lat: 30.0107, lng: 30.9728),
        ],
        optimizedRoute: [
          OptimizedRoute(lat: 30.0444, lng: 31.2357),
          OptimizedRoute(lat: 30.0107, lng: 30.9728),
        ],
        driverToPickup: DriverToPickup(distance: 1200, duration: 240),
        pickupToDropoff: DriverToPickup(distance: 18000, duration: 1500),
        driver: AvailableRideDriver(
          id: 'driver-123',
          firstName: 'Ahmed',
          lastName: 'Hassan',
          carDetails: AvailableRideCarDetails(make: 'Toyota', model: 'Corolla'),
        ),
      ),
    ]);
    super.onInit();
  }

  @override
  void onReady() {
    assignMarkers();
    requestState.value = RequestState.success;
  }

  @override
  Future<void> bookRide({required String rideId}) async {
    state.requestSent = true;
    await userTripsController.getRides(showLoading: false);
    Get.toNamed(AppRoutesNames.userTripsScreen);
  }
}

class HappyPathUserTripsController extends UserTripsController {
  HappyPathUserTripsController(this.state);

  final HappyPathState state;

  @override
  void initialServices() {
    requestId = state.requestId;
  }

  @override
  void onReady() {
    getRides();
  }

  @override
  Future<void> getRides({bool showLoading = true}) async {
    if (showLoading) {
      requestState.value = RequestState.loading;
    }

    if (!state.requestSent) {
      userRides.clear();
      changeScreenTitle();
      requestState.value = RequestState.none;
      return;
    }

    userRides.assignAll([
      UserRidesModel(
        rideId: state.rideId,
        requestId: state.requestId,
        availableSeats: 3,
        createdAt: '2026-03-13T00:00:00.000Z',
        status: state.accepted ? 'accepted' : 'pending',
        driver: Driver(
          firstName: 'Ahmed',
          lastName: 'Hassan',
          carDetails: CarDetails(
            make: 'Toyota',
            model: 'Corolla',
            licensePlate: 'ABC-1234',
          ),
        ),
      ),
    ]);
    changeScreenTitle();
    requestState.value = RequestState.success;
  }
}

class HappyPathTrackRideController extends TrackRideController {
  HappyPathTrackRideController(this.state);

  final HappyPathState state;

  @override
  Future<void> initialServices() async {
    rideId = state.rideId;
    liveStatusText.value = 'Driver is heading to your pickup';
    pickupLabel.value = state.pickupLabel;
    dropoffLabel.value = state.dropoffLabel;
    distance.value = 3200;
    etaMinutes.value = 7;
    markers.assignAll([
      Marker(
        point: LatLng(30.0444, 31.2357),
        child: const Icon(Icons.location_on),
      ),
      Marker(
        point: LatLng(30.0107, 30.9728),
        child: const Icon(Icons.directions_car),
      ),
    ]);
    routes.assignAll([
      LatLng(30.0444, 31.2357),
      LatLng(30.0107, 30.9728),
    ]);
    requestState.value = RequestState.success;
    update();
  }

  @override
  void startTracking() {}

  @override
  Future<void> refreshLiveRideData({bool showLoading = false}) async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Driver/client happy path', () {
    setUp(() async {
      Get.testMode = false;
      Get.reset();
      SharedPreferences.setMockInitialValues({});
      app.sharedPreferences = await SharedPreferences.getInstance();
      await app.sharedPreferences.clear();
    });

    tearDown(() {
      Get.reset();
    });

    testWidgets(
      'driver creates ride, client requests, driver accepts, client sees accepted trip without manual re-entry',
      (tester) async {
        final state = HappyPathState();
        Get.put(DioClient());
        final tripsController = HappyPathUserTripsController(state);
        final availableRidesController = HappyPathAvailableRidesController(
          state: state,
          userTripsController: tripsController,
        );
        final trackRideController = HappyPathTrackRideController(state);
        final fakeDriverService = FakeDriverService(
          initialRideId: state.rideId,
          rideDataResponse: {
            'route': [
              {'lat': 30.0444, 'lng': 31.2357},
              {'lat': 30.0107, 'lng': 30.9728},
            ],
            'passengers': <Map<String, dynamic>>[],
          },
        );
        final driverActiveRideController = DriverActiveRideController(
          driverService: fakeDriverService,
          enableLocationBootstrap: false,
        );

        Get.put<UserTripsController>(tripsController);
        Get.put<AvailableRidesController>(availableRidesController);
        Get.put<TrackRideController>(trackRideController);

        driverActiveRideController.onInit();

        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) {
              ScreenSize.init(context);
              return child!;
            },
            initialRoute: AppRoutesNames.availableRides,
            getPages: [
              GetPage(
                name: AppRoutesNames.availableRides,
                page: () => const AvailableRidesScreen(),
              ),
              GetPage(
                name: AppRoutesNames.userTripsScreen,
                page: () => const UserTripsScreen(),
              ),
              GetPage(
                name: AppRoutesNames.trackRequestScreen,
                page: () => const TrackRideScreen(),
              ),
            ],
          ),
        );
        await safePumpAndSettle(tester);

        expect(find.text('Available Rides'), findsOneWidget);
        expect(find.text('Ahmed Hassan'), findsOneWidget);
        expect(find.text('Book Ride'), findsOneWidget);

        await availableRidesController.bookRide(rideId: state.rideId);
        await safePumpAndSettle(tester);

        expect(find.text('Your Trips'), findsOneWidget);
        expect(find.text('PENDING'), findsOneWidget);

        state.accepted = true;
        fakeDriverService.rideDataResponse = {
          'route': [
            {'lat': 30.0444, 'lng': 31.2357},
            {'lat': 30.0107, 'lng': 30.9728},
          ],
          'passengers': [
            {
              'requestId': state.requestId,
              'name': 'Sara Ali',
              'rating': 4.9,
              'price': 45,
              'pickedUp': false,
              'droppedOff': false,
              'pickup': state.pickupLabel,
              'dropoff': state.dropoffLabel,
              'pickupLocation': {'lat': 30.0444, 'lng': 31.2357},
              'dropoffLocation': {'lat': 30.0107, 'lng': 30.9728},
            },
          ],
        };

        await driverActiveRideController.loadRideData();
        await tripsController.getRides(showLoading: false);
        await safePumpAndSettle(tester);

        expect(driverActiveRideController.passengers, hasLength(1));
        expect(driverActiveRideController.passengers.single['name'], 'Sara Ali');
        expect(find.text('ACCEPTED'), findsOneWidget);
        expect(find.text('Track Ride'), findsOneWidget);

        await tester.tap(find.text('Track Ride'));
        await safePumpAndSettle(tester);

        expect(find.text('Track Ride'), findsWidgets);
        expect(find.text('Driver is heading to your pickup'), findsOneWidget);
        expect(find.text(state.pickupLabel), findsOneWidget);
        expect(find.text(state.dropoffLabel), findsOneWidget);
        expect(find.text('7 min'), findsOneWidget);

        driverActiveRideController.onClose();
      },
    );
  });
}
