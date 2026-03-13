import 'package:flutter_test/flutter_test.dart';
import 'package:tariqi/models/availaible_rides_model.dart';

void main() {
  group('AvailaibleRidesModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'rideId': 'ride123',
        'availableSeats': 3,
        'optimizedRoute': [
          {'lat': 30.0444, 'lng': 31.2357},
          {'lat': 30.0131, 'lng': 31.2089},
        ],
        'pickupIndex': 1,
        'dropoffIndex': 2,
        'additionalDuration': 120.5,
        'driverToPickup': {'distance': 5000.0, 'duration': 600.0},
        'pickupToDropoff': {'distance': 10000.0, 'duration': 1200.0},
      };

      final model = AvailaibleRidesModel.fromJson(json);

      expect(model.rideId, 'ride123');
      expect(model.availableSeats, 3);
      expect(model.optimizedRoute!.length, 2);
      expect(model.pickupIndex, 1);
      expect(model.dropoffIndex, 2);
      expect(model.additionalDuration, 120.5);
      expect(model.driverToPickup!.distance, 5000.0);
      expect(model.pickupToDropoff!.duration, 1200.0);
    });

    test('fromJson handles null optional fields', () {
      final json = {'rideId': 'ride123', 'availableSeats': 2};

      final model = AvailaibleRidesModel.fromJson(json);

      expect(model.rideId, 'ride123');
      expect(model.optimizedRoute, isNull);
      expect(model.driverToPickup, isNull);
      expect(model.pickupToDropoff, isNull);
      expect(model.additionalDuration, isNull);
    });

    test('fromJson handles empty optimizedRoute', () {
      final json = {
        'rideId': 'ride123',
        'availableSeats': 1,
        'optimizedRoute': [],
      };

      final model = AvailaibleRidesModel.fromJson(json);
      expect(model.optimizedRoute, isEmpty);
    });
  });

  group('OptimizedRoute', () {
    test('fromJson parses coordinates', () {
      final json = {'lat': 30.0444, 'lng': 31.2357};
      final route = OptimizedRoute.fromJson(json);
      expect(route.lat, 30.0444);
      expect(route.lng, 31.2357);
    });

    test('fromJson handles null values', () {
      final route = OptimizedRoute.fromJson({});
      expect(route.lat, isNull);
      expect(route.lng, isNull);
    });
  });

  group('DriverToPickup', () {
    test('fromJson parses distance and duration', () {
      final json = {'distance': 5000.0, 'duration': 600.0};
      final dtp = DriverToPickup.fromJson(json);
      expect(dtp.distance, 5000.0);
      expect(dtp.duration, 600.0);
    });

    test('fromJson handles null values', () {
      final dtp = DriverToPickup.fromJson({});
      expect(dtp.distance, isNull);
      expect(dtp.duration, isNull);
    });
  });
}
