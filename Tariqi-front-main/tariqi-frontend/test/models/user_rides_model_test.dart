import 'package:flutter_test/flutter_test.dart';
import 'package:tariqi/models/user_rides_model.dart';

void main() {
  group('UserRidesModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'rideId': 'ride123',
        'route': [
          {'lat': 30.0444, 'lng': 31.2357},
          {'lat': 30.0131, 'lng': 31.2089},
        ],
        'availableSeats': 3,
        'createdAt': '2026-03-09T10:00:00.000Z',
        'status': 'accepted',
        'driver': {
          '_id': 'driver123',
          'firstName': 'Ahmed',
          'lastName': 'Hassan',
          'age': '35',
          'phoneNumber': '+201234567890',
          'carDetails': {
            'make': 'Toyota',
            'model': 'Corolla',
            'licensePlate': 'ABC-1234',
          },
        },
      };

      final model = UserRidesModel.fromJson(json);

      expect(model.rideId, 'ride123');
      expect(model.route!.length, 2);
      expect(model.route![0].lat, 30.0444);
      expect(model.availableSeats, 3);
      expect(model.status, 'accepted');
      expect(model.driver!.firstName, 'Ahmed');
      expect(model.driver!.carDetails!.make, 'Toyota');
    });

    test('fromJson handles null optional fields', () {
      final json = {'rideId': 'ride123', 'status': 'pending'};

      final model = UserRidesModel.fromJson(json);

      expect(model.route, isNull);
      expect(model.driver, isNull);
      expect(model.availableSeats, isNull);
    });

    test('fromJson handles empty route', () {
      final json = {'rideId': 'ride123', 'route': []};

      final model = UserRidesModel.fromJson(json);
      expect(model.route, isEmpty);
    });
  });

  group('Routes', () {
    test('fromJson parses coordinates', () {
      final route = Routes.fromJson({'lat': 30.0444, 'lng': 31.2357});
      expect(route.lat, 30.0444);
      expect(route.lng, 31.2357);
    });
  });

  group('Driver', () {
    test('fromJson parses complete driver', () {
      final json = {
        '_id': 'driver123',
        'firstName': 'Ahmed',
        'lastName': 'Hassan',
        'age': '35',
        'phoneNumber': '+201234567890',
        'id': 'driver123',
        'carDetails': {
          'make': 'Toyota',
          'model': 'Corolla',
          'licensePlate': 'ABC-1234',
        },
      };

      final driver = Driver.fromJson(json);

      expect(driver.sId, 'driver123');
      expect(driver.firstName, 'Ahmed');
      expect(driver.carDetails!.licensePlate, 'ABC-1234');
    });

    test('fromJson handles missing carDetails', () {
      final driver = Driver.fromJson({
        '_id': 'driver123',
        'firstName': 'Ahmed',
      });
      expect(driver.carDetails, isNull);
    });
  });

  group('CarDetails', () {
    test('fromJson parses car details', () {
      final car = CarDetails.fromJson({
        'make': 'Toyota',
        'model': 'Corolla',
        'licensePlate': 'ABC-1234',
      });
      expect(car.make, 'Toyota');
      expect(car.model, 'Corolla');
      expect(car.licensePlate, 'ABC-1234');
    });
  });
}
