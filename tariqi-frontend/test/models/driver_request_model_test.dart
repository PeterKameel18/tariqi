import 'package:flutter_test/flutter_test.dart';
import 'package:tariqi/models/driver_request_model.dart';

void main() {
  group('DriverRequest', () {
    group('fromJson', () {
      test('parses complete data correctly', () {
        final json = {
          'id': 'req123',
          'driverId': 'driver456',
          'name': 'Ahmed Hassan',
          'profilePicture': 'https://example.com/pic.jpg',
          'rating': 4.8,
          'totalRides': 150,
          'arrivalTime': '10 mins',
          'carModel': 'Toyota Camry 2022',
          'carPlate': 'ABC-1234',
          'phoneNumber': '01012345678',
          'latitude': 30.0444,
          'longitude': 31.2357,
        };
        final driver = DriverRequest.fromJson(json);
        expect(driver.id, 'req123');
        expect(driver.driverId, 'driver456');
        expect(driver.name, 'Ahmed Hassan');
        expect(driver.profilePicture, 'https://example.com/pic.jpg');
        expect(driver.rating, 4.8);
        expect(driver.totalRides, 150);
        expect(driver.arrivalTime, '10 mins');
        expect(driver.carModel, 'Toyota Camry 2022');
        expect(driver.carPlate, 'ABC-1234');
        expect(driver.phoneNumber, '01012345678');
        expect(driver.latitude, 30.0444);
        expect(driver.longitude, 31.2357);
      });

      test('uses defaults for missing required fields', () {
        final json = <String, dynamic>{};
        final driver = DriverRequest.fromJson(json);
        expect(driver.id, '');
        expect(driver.driverId, '');
        expect(driver.name, 'Unknown Driver');
        expect(driver.rating, 4.5);
        expect(driver.totalRides, 0);
        expect(driver.arrivalTime, '15 mins');
        expect(driver.carModel, 'Unknown Model');
        expect(driver.carPlate, 'Unknown');
        expect(driver.latitude, 0.0);
        expect(driver.longitude, 0.0);
      });

      test('handles null optional fields (profilePicture, phoneNumber)', () {
        final json = {
          'id': 'req1',
          'driverId': 'drv1',
          'name': 'Test',
          'rating': 4.0,
          'totalRides': 5,
          'arrivalTime': '5 mins',
          'carModel': 'BMW',
          'carPlate': 'XYZ',
          'latitude': 30.0,
          'longitude': 31.0,
        };
        final driver = DriverRequest.fromJson(json);
        expect(driver.profilePicture, isNull);
        expect(driver.phoneNumber, isNull);
      });

      test('converts integer rating to double', () {
        final json = {'rating': 5, 'latitude': 30, 'longitude': 31};
        final driver = DriverRequest.fromJson(json);
        expect(driver.rating, 5.0);
        expect(driver.rating, isA<double>());
      });

      test('converts integer coordinates to double', () {
        final json = {'latitude': 30, 'longitude': 31};
        final driver = DriverRequest.fromJson(json);
        expect(driver.latitude, 30.0);
        expect(driver.latitude, isA<double>());
        expect(driver.longitude, 31.0);
        expect(driver.longitude, isA<double>());
      });

      test('handles zero rating and totalRides', () {
        final json = {'rating': 0, 'totalRides': 0, 'latitude': 0, 'longitude': 0};
        final driver = DriverRequest.fromJson(json);
        // Dart ?? operator only checks for null, not falsiness
        // So rating 0 stays as 0.0, not the default 4.5
        expect(driver.rating, 0.0);
        expect(driver.totalRides, 0);
      });

      test('handles negative coordinates (southern/western hemisphere)', () {
        final json = {'latitude': -33.8688, 'longitude': -151.2093};
        final driver = DriverRequest.fromJson(json);
        expect(driver.latitude, -33.8688);
        expect(driver.longitude, -151.2093);
      });

      test('handles very large totalRides count', () {
        final json = {'totalRides': 999999, 'latitude': 0, 'longitude': 0};
        final driver = DriverRequest.fromJson(json);
        expect(driver.totalRides, 999999);
      });

      test('handles unicode characters in name', () {
        final json = {
          'name': 'محمد أحمد',
          'latitude': 30.0,
          'longitude': 31.0,
        };
        final driver = DriverRequest.fromJson(json);
        expect(driver.name, 'محمد أحمد');
      });

      test('handles empty string name', () {
        final json = {'name': '', 'latitude': 30.0, 'longitude': 31.0};
        final driver = DriverRequest.fromJson(json);
        // Empty string is not null/falsy in Dart, so it's used as-is
        expect(driver.name, '');
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final driver = DriverRequest(
          id: 'req123',
          driverId: 'driver456',
          name: 'Ahmed',
          profilePicture: 'pic.jpg',
          rating: 4.8,
          totalRides: 100,
          arrivalTime: '10 mins',
          carModel: 'Toyota',
          carPlate: 'ABC',
          phoneNumber: '01012345678',
          latitude: 30.0444,
          longitude: 31.2357,
        );
        final json = driver.toJson();
        expect(json['id'], 'req123');
        expect(json['driverId'], 'driver456');
        expect(json['name'], 'Ahmed');
        expect(json['profilePicture'], 'pic.jpg');
        expect(json['rating'], 4.8);
        expect(json['totalRides'], 100);
        expect(json['arrivalTime'], '10 mins');
        expect(json['carModel'], 'Toyota');
        expect(json['carPlate'], 'ABC');
        expect(json['phoneNumber'], '01012345678');
        expect(json['latitude'], 30.0444);
        expect(json['longitude'], 31.2357);
      });

      test('serializes null optional fields', () {
        final driver = DriverRequest(
          id: 'req1',
          driverId: 'drv1',
          name: 'Test',
          rating: 4.0,
          totalRides: 0,
          arrivalTime: '5 mins',
          carModel: 'BMW',
          carPlate: 'XYZ',
          latitude: 30.0,
          longitude: 31.0,
        );
        final json = driver.toJson();
        expect(json['profilePicture'], isNull);
        expect(json['phoneNumber'], isNull);
      });

      test('roundtrip: fromJson -> toJson preserves data', () {
        final original = {
          'id': 'req123',
          'driverId': 'driver456',
          'name': 'Ahmed',
          'profilePicture': 'pic.jpg',
          'rating': 4.8,
          'totalRides': 100,
          'arrivalTime': '10 mins',
          'carModel': 'Toyota',
          'carPlate': 'ABC',
          'phoneNumber': '01012345678',
          'latitude': 30.0444,
          'longitude': 31.2357,
        };
        final driver = DriverRequest.fromJson(original);
        final restored = driver.toJson();
        expect(restored['id'], original['id']);
        expect(restored['name'], original['name']);
        expect(restored['rating'], original['rating']);
        expect(restored['latitude'], original['latitude']);
        expect(restored['longitude'], original['longitude']);
      });
    });
  });
}
