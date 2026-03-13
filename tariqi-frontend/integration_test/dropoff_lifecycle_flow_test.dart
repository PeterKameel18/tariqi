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
import 'package:tariqi/controller/auth_controllers/auth_controller.dart';
import 'package:tariqi/controller/driver/driver_active_ride_controller.dart';
import 'package:tariqi/controller/notification_controller.dart';
import 'package:tariqi/controller/track_ride_controller/track_ride_controller.dart';
import 'package:tariqi/controller/user_trips_controller/user_trips_controller.dart';
import 'package:tariqi/models/app_notification.dart';
import 'package:tariqi/models/user_rides_model.dart';
import 'package:tariqi/services/driver_service.dart';
import 'package:tariqi/view/driver/driver_active_ride_screen.dart';
import 'package:tariqi/view/track_ride_screen/track_ride_screen.dart';
import 'package:tariqi/view/trips_screen/user_trips_screen.dart';
import 'package:tariqi/main.dart' as app;

import '../test/helpers/auth_test_helpers.dart';
import '../test/helpers/ride_test_helpers.dart';
import 'test_helpers.dart';

class DropoffFlowState {
  final String rideId = 'ride-dropoff-123';
  final String requestId = 'request-dropoff-123';
  final String pickupLabel = 'Tahrir Square';
  final String dropoffLabel = 'Sheikh Zayed';
  final String passengerName = 'Sara Ali';
  bool droppedOff = false;
  bool driverRouteStabilized = false;
}

class DropoffUserTripsController extends UserTripsController {
  DropoffUserTripsController(this.state);

  final DropoffFlowState state;

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

    userRides.assignAll([
      UserRidesModel(
        rideId: state.rideId,
        requestId: state.requestId,
        availableSeats: 3,
        createdAt: '2026-03-13T00:00:00.000Z',
        status: state.droppedOff ? 'finished' : 'accepted',
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

class DropoffTrackRideController extends TrackRideController {
  DropoffTrackRideController(this.state);

  final DropoffFlowState state;

  void _seedAcceptedState() {
    rideId = state.rideId;
    liveStatusText.value = 'You are onboard';
    pickupLabel.value = state.pickupLabel;
    dropoffLabel.value = state.dropoffLabel;
    distance.value = 1800;
    etaMinutes.value = 4;
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
  Future<void> initialServices() async {
    _seedAcceptedState();
  }

  @override
  void startTracking() {}

  @override
  Future<void> refreshLiveRideData({bool showLoading = false}) async {
    if (state.droppedOff) {
      routes.clear();
      markers.clear();
      requestState.value = RequestState.none;
      Get.offNamed(AppRoutesNames.userTripsScreen);
      return;
    }

    _seedAcceptedState();
  }
}

class FakeNotificationController extends NotificationController {
  @override
  Future<void> loadNotifications() async {
    notifications.assignAll([
      AppNotification(
        id: 'notif-1',
        type: 'test',
        title: 'Test',
        message: 'Test',
        recipientId: 'driver',
        createdAt: DateTime(2026, 3, 13),
        read: true,
      ),
    ]);
  }
}

class DropoffDriverActiveRideController extends DriverActiveRideController {
  DropoffDriverActiveRideController({
    required this.state,
    required this.driverService,
  }) : super(
         driverService: driverService,
         enableLocationBootstrap: false,
       );

  final DropoffFlowState state;
  final DriverService driverService;

  void seedAcceptedPassenger() {
    rideId = state.rideId;
    destination = 'Original destination';
    distanceKm = 14.2;
    etaMinutes = 24;
    currentLocation = const LatLng(30.0444, 31.2357);
    destinationLocation = const LatLng(30.0131, 31.2089);
    requestState.value = RequestState.online;
    passengers.assignAll([
      {
        'id': state.requestId,
        'name': state.passengerName,
        'rating': 4.9,
        'profilePic': '',
        'price': 45,
        'pickedUp': true,
        'droppedOff': false,
        'pickup': state.pickupLabel,
        'dropoff': state.dropoffLabel,
        'pickupLocation': const LatLng(30.0444, 31.2357),
        'dropoffLocation': const LatLng(30.0107, 30.9728),
      },
    ]);
    update();
  }

  @override
  Future<void> checkAndRouteToDestination() async {
    state.driverRouteStabilized = true;
    destination = 'Original destination';
    distanceKm = 11.8;
    etaMinutes = 18;
    requestState.value = RequestState.online;
    update();
  }

  @override
  Future<void> dropoffPassenger(String requestId) async {
    state.droppedOff = true;
    requestState.value = RequestState.loading;

    final passengerIndex = passengers.indexWhere((p) => p['id'] == requestId);
    if (passengerIndex == -1) {
      requestState.value = RequestState.failed;
      update();
      return;
    }

    final success = await driverService.dropoffPassenger(requestId);
    if (!success) {
      requestState.value = RequestState.failed;
      update();
      return;
    }

    passengers.removeAt(passengerIndex);
    if (rideId != null && rideId!.isNotEmpty) {
      await driverService.savePassengers(rideId!, passengers.toList());
    }
    await checkAndRouteToDestination();
    requestState.value = RequestState.online;
    update();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Dropoff lifecycle', () {
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
      'accepted trip drops off cleanly for driver and client without stale active state',
      (tester) async {
        final state = DropoffFlowState();
        final fakeDriverService = FakeDriverService(initialRideId: state.rideId);
        final userTripsController = DropoffUserTripsController(state);
        final trackRideController = DropoffTrackRideController(state);
        final driverController = DropoffDriverActiveRideController(
          state: state,
          driverService: fakeDriverService,
        );
        final authController = FakeAuthController()..token.value = 'test-token';

        Get.put<AuthController>(authController);
        Get.put<DriverService>(fakeDriverService);
        Get.put<UserTripsController>(userTripsController);
        Get.put<TrackRideController>(trackRideController);
        Get.put<DriverActiveRideController>(driverController);
        Get.put<NotificationController>(FakeNotificationController());

        driverController.onInit();
        driverController.seedAcceptedPassenger();

        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) {
              ScreenSize.init(context);
              return child!;
            },
            initialRoute: AppRoutesNames.trackRequestScreen,
            getPages: [
              GetPage(
                name: AppRoutesNames.trackRequestScreen,
                page: () => const TrackRideScreen(),
              ),
              GetPage(
                name: AppRoutesNames.driverActiveRideScreen,
                page: () => const DriverActiveRideScreen(),
              ),
              GetPage(
                name: AppRoutesNames.userTripsScreen,
                page: () => const UserTripsScreen(),
              ),
            ],
          ),
        );
        await safePumpAndSettle(tester);

        expect(find.text('Track Ride'), findsWidgets);
        expect(find.text('You are onboard'), findsOneWidget);
        expect(find.text(state.pickupLabel), findsOneWidget);
        expect(find.text(state.dropoffLabel), findsOneWidget);
        expect(driverController.passengers, hasLength(1));

        await driverController.dropoffPassenger(state.requestId);
        await safePumpAndSettle(tester);

        expect(state.droppedOff, isTrue);
        expect(driverController.passengers, isEmpty);
        expect(state.driverRouteStabilized, isTrue);

        Get.toNamed(
          AppRoutesNames.driverActiveRideScreen,
          arguments: {'rideId': state.rideId},
        );
        await safePumpAndSettle(tester);

        expect(find.text('Active Ride'), findsOneWidget);
        expect(find.text(state.passengerName), findsNothing);
        expect(driverController.destination, 'Original destination');
        expect(driverController.requestState.value, RequestState.online);

        await trackRideController.refreshLiveRideData();
        await userTripsController.getRides(showLoading: false);
        await safePumpAndSettle(tester);

        expect(find.text('Your Trips'), findsOneWidget);
        expect(find.text('FINISHED'), findsOneWidget);
        expect(find.text('Track Ride'), findsNothing);
      },
    );
  });
}
