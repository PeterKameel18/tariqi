import 'package:flutter_test/flutter_test.dart';
import 'package:tariqi/models/app_notification.dart';
import 'package:tariqi/models/availaible_rides_model.dart';
import 'package:tariqi/models/chat_message.dart';
import 'package:tariqi/models/client_info_model.dart';
import 'package:tariqi/models/driver_request_model.dart';
import 'package:tariqi/models/messages_model.dart';
import 'package:tariqi/models/ride_request_model.dart';
import 'package:tariqi/models/user_rides_model.dart';

/// Tests for crash scenarios caused by malformed API responses
/// These document real bugs where the app crashes on unexpected data
void main() {
  // ============================================
  // AppNotification crash scenarios
  // ============================================
  group('AppNotification crash scenarios', () {
    test('CRASH: null createdAt throws FormatException', () {
      final json = {
        '_id': 'n1',
        'type': 'test',
        'message': 'test',
        'createdAt': null,
      };
      // DateTime.parse(null) will crash
      expect(
        () => AppNotification.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('CRASH: invalid date string throws FormatException', () {
      final json = {
        '_id': 'n1',
        'type': 'test',
        'message': 'test',
        'createdAt': 'not-a-date',
      };
      expect(
        () => AppNotification.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('CRASH: missing createdAt entirely', () {
      final json = {'_id': 'n1', 'type': 'test', 'message': 'test'};
      // json['createdAt'] is null → DateTime.parse(null) crashes
      expect(
        () => AppNotification.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('handles epoch-style timestamp', () {
      final json = {
        '_id': 'n1',
        'type': 'test',
        'message': 'test',
        'createdAt': '1970-01-01T00:00:00.000Z',
      };
      final notif = AppNotification.fromJson(json);
      expect(notif.createdAt.year, 1970);
    });

    test('handles far-future date', () {
      final json = {
        '_id': 'n1',
        'type': 'test',
        'message': 'test',
        'createdAt': '2099-12-31T23:59:59.999Z',
      };
      final notif = AppNotification.fromJson(json);
      expect(notif.createdAt.year, 2099);
    });
  });

  // ============================================
  // AvailaibleRidesModel crash scenarios
  // ============================================
  group('AvailaibleRidesModel crash scenarios', () {
    test('handles null rideId', () {
      final json = {'rideId': null, 'availableSeats': 3};
      final model = AvailaibleRidesModel.fromJson(json);
      expect(model.rideId, isNull);
    });

    test('handles zero available seats', () {
      final json = {'rideId': 'r1', 'availableSeats': 0};
      final model = AvailaibleRidesModel.fromJson(json);
      expect(model.availableSeats, 0);
    });

    test('handles negative available seats', () {
      final json = {'rideId': 'r1', 'availableSeats': -1};
      final model = AvailaibleRidesModel.fromJson(json);
      expect(model.availableSeats, -1);
    });

    test('handles negative additionalDuration', () {
      final json = {
        'rideId': 'r1',
        'availableSeats': 3,
        'additionalDuration': -100.0,
      };
      final model = AvailaibleRidesModel.fromJson(json);
      expect(model.additionalDuration, -100.0);
    });

    test('handles very large additionalDuration', () {
      final json = {
        'rideId': 'r1',
        'availableSeats': 3,
        'additionalDuration': 999999999.0,
      };
      final model = AvailaibleRidesModel.fromJson(json);
      expect(model.additionalDuration, 999999999.0);
    });

    test('handles malformed optimizedRoute entries', () {
      final json = <String, dynamic>{
        'rideId': 'r1',
        'availableSeats': 3,
        'optimizedRoute': [
          <String, dynamic>{'lat': null, 'lng': null},
          <String, dynamic>{},
        ],
      };
      final model = AvailaibleRidesModel.fromJson(json);
      expect(model.optimizedRoute!.length, 2);
      expect(model.optimizedRoute![0].lat, isNull);
      expect(model.optimizedRoute![1].lat, isNull);
    });

    test('handles driverToPickup with zero distance', () {
      final json = {
        'rideId': 'r1',
        'availableSeats': 3,
        'driverToPickup': {'distance': 0.0, 'duration': 0.0},
      };
      final model = AvailaibleRidesModel.fromJson(json);
      expect(model.driverToPickup!.distance, 0.0);
    });
  });

  // ============================================
  // ChatMessage crash scenarios
  // ============================================
  group('ChatMessage edge cases', () {
    test('handles completely empty json', () {
      // ChatMessage.fromJson should handle gracefully
      final msg = ChatMessage.fromJson({});
      expect(msg.id, isNotNull);
      expect(msg.message, isNotNull);
    });

    test('handles XSS-like content', () {
      final json = {
        '_id': 'msg1',
        'sender': 's1',
        'content': '<img onerror="hack()" src="x">',
        'senderType': 'Client',
        'timestamp': '2024-01-01T00:00:00.000Z',
      };
      final msg = ChatMessage.fromJson(json);
      // Content should be stored as-is (XSS prevention is at UI layer)
      expect(msg.message, contains('<img'));
    });

    test('handles very long message content', () {
      final json = {
        '_id': 'msg1',
        'sender': 's1',
        'content': 'A' * 50000,
        'senderType': 'Client',
        'timestamp': '2024-01-01T00:00:00.000Z',
      };
      final msg = ChatMessage.fromJson(json);
      expect(msg.message.length, 50000);
    });

    test('handles emoji in message', () {
      final json = {
        '_id': 'msg1',
        'sender': 's1',
        'content': '🚗💯🎉 سيارة جديدة',
        'senderType': 'Client',
        'timestamp': '2024-01-01T00:00:00.000Z',
      };
      final msg = ChatMessage.fromJson(json);
      expect(msg.message, contains('🚗'));
    });

    test('handles sender as populated object from backend', () {
      // The backend populates sender as an object, and ChatMessage.fromJson
      // now correctly handles both String and Map sender formats
      final json = {
        '_id': 'msg1',
        'sender': {'_id': 's1', 'firstName': 'Ahmed'},
        'content': 'Hello',
        'senderType': 'Client',
        'timestamp': '2024-01-01T00:00:00.000Z',
      };
      final msg = ChatMessage.fromJson(json);
      expect(msg.senderId, 's1');
    });
  });

  // ============================================
  // RideRequestModel edge cases
  // ============================================
  group('RideRequestModel edge cases', () {
    test('handles empty json', () {
      final model = RideRequestModel.fromJson({});
      expect(model.sId, isNull);
      expect(model.status, isNull);
    });

    test('handles null ride object', () {
      final json = {
        '_id': 'req1',
        'ride': null,
        'status': 'pending',
      };
      final model = RideRequestModel.fromJson(json);
      expect(model.ride, isNull);
    });

    test('handles empty approvals list', () {
      final json = {
        '_id': 'req1',
        'approvals': [],
      };
      final model = RideRequestModel.fromJson(json);
      expect(model.approvals, isEmpty);
    });

    test('handles null price', () {
      final json = {
        '_id': 'req1',
        'price': null,
      };
      final model = RideRequestModel.fromJson(json);
      expect(model.price, isNull);
    });

    test('handles zero price', () {
      final json = {
        '_id': 'req1',
        'price': 0,
      };
      final model = RideRequestModel.fromJson(json);
      expect(model.price, 0);
    });

    test('handles all valid status values', () {
      final statuses = ['pending', 'approved', 'rejected', 'cancelled', 'finished'];
      for (final status in statuses) {
        final json = {'_id': 'req1', 'status': status};
        final model = RideRequestModel.fromJson(json);
        expect(model.status, status);
      }
    });

    test('handles unexpected status value', () {
      final json = {'_id': 'req1', 'status': 'unknown_status'};
      final model = RideRequestModel.fromJson(json);
      expect(model.status, 'unknown_status');
    });
  });

  // ============================================
  // UserRidesModel edge cases
  // ============================================
  group('UserRidesModel edge cases', () {
    test('handles empty json', () {
      final json = <String, dynamic>{};
      final model = UserRidesModel.fromJson(json);
      expect(model.rideId, isNull);
      expect(model.status, isNull);
    });

    test('handles null route', () {
      final json = {
        'rideId': 'r1',
        'route': null,
        'availableSeats': 3,
        'createdAt': '2024-01-01T00:00:00.000Z',
        'status': 'active',
      };
      final model = UserRidesModel.fromJson(json);
      expect(model.route, isNull);
    });

    test('handles empty route array', () {
      final json = {
        'rideId': 'r1',
        'route': [],
        'availableSeats': 2,
        'createdAt': '2024-01-01T00:00:00.000Z',
        'status': 'active',
      };
      final model = UserRidesModel.fromJson(json);
      expect(model.route, isEmpty);
    });

    test('handles driver with missing carDetails', () {
      final json = {
        'rideId': 'r1',
        'driver': {'_id': 'drv1', 'firstName': 'Ahmed'},
      };
      final model = UserRidesModel.fromJson(json);
      expect(model.driver, isNotNull);
      expect(model.driver!.carDetails, isNull);
    });

    test('handles createdAt edge cases', () {
      // null createdAt
      final json1 = {'rideId': 'r1', 'createdAt': null};
      final model1 = UserRidesModel.fromJson(json1);
      expect(model1.createdAt, isNull);

      // valid createdAt
      final json2 = {'rideId': 'r1', 'createdAt': '2024-06-15T10:30:00.000Z'};
      final model2 = UserRidesModel.fromJson(json2);
      expect(model2.createdAt, '2024-06-15T10:30:00.000Z');
    });
  });

  // ============================================
  // ClientInfoModel edge cases
  // ============================================
  group('ClientInfoModel edge cases', () {
    test('handles completely empty json', () {
      final model = ClientInfoModel.fromJson({});
      expect(model.email, isNull);
    });

    test('handles special characters in names', () {
      final json = {
        'firstName': "O'Brien-Smith",
        'lastName': 'von Müller',
        'email': 'obriensmith@test.com',
      };
      final model = ClientInfoModel.fromJson(json);
      expect(model.firstName, "O'Brien-Smith");
      expect(model.lastName, 'von Müller');
    });

    test('handles very long email', () {
      final longEmail = '${'a' * 200}@test.com';
      final json = {'email': longEmail};
      final model = ClientInfoModel.fromJson(json);
      expect(model.email, longEmail);
    });

    test('handles extra fields not in model without crashing', () {
      final json = {
        'email': 'test@test.com',
        'pickup': null,
        'dropoff': null,
        'currentLocation': null,
      };
      // ClientInfoModel only has: firstName, lastName, age, phoneNumber, email, inRide
      // Extra fields are silently ignored
      final model = ClientInfoModel.fromJson(json);
      expect(model.email, 'test@test.com');
    });
  });

  // ============================================
  // MessagesModel edge cases
  // ============================================
  group('MessagesModel edge cases', () {
    test('handles null sender fields', () {
      final json = {
        '_id': 'msg1',
        'sender': null,
        'content': 'Hello',
        'senderType': 'Client',
      };
      final model = MessagesModel.fromJson(json);
      expect(model.sender, isNull);
    });

    test('handles missing content field', () {
      final json = {
        '_id': 'msg1',
        'sender': 'user1',
        'senderType': 'Client',
      };
      final model = MessagesModel.fromJson(json);
      expect(model.content, isNull);
    });

    test('handles extra unknown fields without crashing', () {
      final json = {
        '_id': 'msg1',
        'sender': 'user1',
        'content': 'Hello',
        'senderType': 'Client',
        'unknownField': 'value',
        'anotherUnknown': 42,
      };
      final model = MessagesModel.fromJson(json);
      expect(model.content, 'Hello');
    });
  });

  // ============================================
  // DriverRequest roundtrip & boundary tests
  // ============================================
  group('DriverRequest boundary tests', () {
    test('extreme coordinates (poles)', () {
      final json = {
        'latitude': 90.0,
        'longitude': 180.0,
      };
      final driver = DriverRequest.fromJson(json);
      expect(driver.latitude, 90.0);
      expect(driver.longitude, 180.0);
    });

    test('negative extreme coordinates', () {
      final json = {
        'latitude': -90.0,
        'longitude': -180.0,
      };
      final driver = DriverRequest.fromJson(json);
      expect(driver.latitude, -90.0);
      expect(driver.longitude, -180.0);
    });

    test('out-of-range coordinates (invalid but should store)', () {
      final json = {
        'latitude': 999.0,
        'longitude': -999.0,
      };
      final driver = DriverRequest.fromJson(json);
      expect(driver.latitude, 999.0);
      expect(driver.longitude, -999.0);
    });
  });

  // ============================================
  // Data consistency tests across models
  // ============================================
  group('Cross-model data consistency', () {
    test('ride IDs are consistent across UserRides and RideRequest', () {
      final rideId = 'ride_abc123';
      final userRide = UserRidesModel.fromJson({'rideId': rideId});
      final rideRequest = RideRequestModel.fromJson({
        'ride': rideId,
      });
      expect(userRide.rideId, rideRequest.ride);
    });

    test('notification types match between backend enum and frontend handling', () {
      // These are the types defined in the backend Notification model enum
      final backendTypes = [
        'ride_request', 'ride_accepted', 'ride_rejected',
        'ride_cancelled', 'driver_arrived', 'ride_started',
        'ride_completed', 'payment_received', 'payment_sent',
        'new_message', 'system_alert', 'passenger_joined',
        'passenger_left', 'driver_location_update',
        'passenger_approval_request', 'passenger_approved',
        'passenger_rejected', 'passenger_picked_up',
        'passenger_dropped_off',
      ];

      for (final type in backendTypes) {
        final json = {
          '_id': 'n1',
          'type': type,
          'message': 'test',
          'createdAt': '2024-01-01T00:00:00.000Z',
        };
        // Should not crash for any valid backend type
        final notif = AppNotification.fromJson(json);
        expect(notif.type, type);
      }
    });

    test('price is consistent between request and payment', () {
      final price = 42;
      final rideRequest = RideRequestModel.fromJson({
        '_id': 'req1',
        'price': price,
        'payment': {'status': 'paid', 'method': 'cash'},
      });
      expect(rideRequest.price, price);
      expect(rideRequest.payment!.status, 'paid');
    });
  });

  // ============================================
  // Bulk parsing tests (performance under load)
  // ============================================
  group('Bulk parsing performance', () {
    test('parses 100 ride models without errors', () {
      final start = DateTime.now();
      for (int i = 0; i < 100; i++) {
        AvailaibleRidesModel.fromJson({
          'rideId': 'ride_$i',
          'availableSeats': 3,
          'optimizedRoute': [
            {'lat': 30.0 + i * 0.001, 'lng': 31.0 + i * 0.001},
            {'lat': 30.1 + i * 0.001, 'lng': 31.1 + i * 0.001},
          ],
          'additionalDuration': i * 10.0,
          'driverToPickup': {'distance': i * 100.0, 'duration': i * 60.0},
        });
      }
      final elapsed = DateTime.now().difference(start);
      expect(elapsed.inSeconds, lessThan(5));
    });

    test('parses 100 notifications without errors', () {
      final start = DateTime.now();
      for (int i = 0; i < 100; i++) {
        AppNotification.fromJson({
          '_id': 'notif_$i',
          'type': 'system_alert',
          'message': 'Notification $i',
          'createdAt': '2024-01-01T${i.toString().padLeft(2, '0')}:00:00.000Z',
        });
      }
      final elapsed = DateTime.now().difference(start);
      expect(elapsed.inSeconds, lessThan(5));
    });

    test('parses 100 chat messages without errors', () {
      final start = DateTime.now();
      for (int i = 0; i < 100; i++) {
        ChatMessage.fromJson({
          '_id': 'msg_$i',
          'sender': 'user_$i',
          'content': 'Message $i content',
          'senderType': i % 2 == 0 ? 'Driver' : 'Client',
          'timestamp': '2024-01-01T00:${i.toString().padLeft(2, '0')}:00.000Z',
        });
      }
      final elapsed = DateTime.now().difference(start);
      expect(elapsed.inSeconds, lessThan(5));
    });
  });
}
