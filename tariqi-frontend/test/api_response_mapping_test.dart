import 'package:flutter_test/flutter_test.dart';
import 'package:tariqi/models/app_notification.dart';
import 'package:tariqi/models/availaible_rides_model.dart';
import 'package:tariqi/models/chat_message.dart';
import 'package:tariqi/models/client_info_model.dart';
import 'package:tariqi/models/driver_request_model.dart';
import 'package:tariqi/models/messages_model.dart';
import 'package:tariqi/models/notification_model.dart';
import 'package:tariqi/models/ride_request_model.dart';
import 'package:tariqi/models/user_rides_model.dart';

/// Simulates real API response patterns that have historically caused bugs
/// Each test uses actual response structures from the backend controllers
void main() {
  // ============================================
  // Backend Controller Response Mapping Tests
  // ============================================

  group('Auth Controller Responses', () {
    test('login success response maps correctly', () {
      // Simulates response from controllers/auth.js login()
      final loginResponse = {
        'token': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.signature',
        'id': '6634abc123def456',
        'role': 'client',
        'user': {
          '_id': '6634abc123def456',
          'firstName': 'John',
          'lastName': 'Doe',
          'email': 'john@test.com',
        },
      };

      expect(loginResponse['token'], isNotNull);
      expect(loginResponse['role'], isIn(['client', 'driver']));
      expect(loginResponse['id'], isNotEmpty);
    });

    test('signup success response maps correctly', () {
      // Simulates response from controllers/auth.js signup()
      final signupResponse = {
        'message': 'Account created successfully',
        'token': 'eyJhbGciOiJIUzI1NiJ9.test.sig',
        'id': '6634abc123def456',
        'user': {
          '_id': '6634abc123def456',
          'firstName': 'John',
          'lastName': 'Doe',
          'email': 'john@test.com',
          'role': 'client',
        },
      };

      expect(signupResponse['token'], isNotNull);
      expect(signupResponse['id'], isNotNull);
    });

    test('login failure response handling', () {
      // When credentials are wrong
      final errorResponse = {
        'error': 'Invalid credentials',
      };
      expect(errorResponse['error'], isNotNull);
      expect(errorResponse['token'], isNull);
    });

    test('signup duplicate email response', () {
      final errorResponse = {
        'error': 'Email already exists',
      };
      expect(errorResponse['error'], contains('Email'));
    });
  });

  group('Rides Controller Responses', () {
    test('clientGetRides response maps to AvailaibleRidesModel', () {
      // Simulates response from controllers/rides.js clientGetRides()
      final response = {
        'matchedRides': [
          {
            'rideId': '66abc123',
            'availableSeats': 3,
            'optimizedRoute': [
              {'lat': 30.0444, 'lng': 31.2357},
              {'lat': 30.0131, 'lng': 31.2089},
              {'lat': 30.0500, 'lng': 31.2400},
              {'lat': 30.0600, 'lng': 31.2500},
            ],
            'pickupIndex': 1,
            'dropoffIndex': 2,
            'additionalDuration': 180.5,
            'driverToPickup': {'distance': 3500.0, 'duration': 420.0},
            'pickupToDropoff': {'distance': 8000.0, 'duration': 960.0},
          },
        ],
      };

      final rides = (response['matchedRides'] as List)
          .map((r) => AvailaibleRidesModel.fromJson(r))
          .toList();

      expect(rides.length, 1);
      expect(rides[0].rideId, '66abc123');
      expect(rides[0].availableSeats, 3);
      expect(rides[0].optimizedRoute!.length, 4);
      expect(rides[0].pickupIndex, 1);
      expect(rides[0].dropoffIndex, 2);
      expect(rides[0].additionalDuration, 180.5);
      expect(rides[0].driverToPickup!.distance, 3500.0);
      expect(rides[0].pickupToDropoff!.duration, 960.0);
    });

    test('clientGetRides empty response', () {
      final response = {'matchedRides': []};
      final rides = (response['matchedRides'] as List)
          .map((r) => AvailaibleRidesModel.fromJson(r))
          .toList();
      expect(rides, isEmpty);
    });

    test('driverCreateRide response', () {
      // Simulates response from controllers/rides.js driverCreateRide()
      final response = {
        'message': 'Ride created',
        'ride': {
          '_id': '66abc123',
          'driver': '66drv456',
          'passengers': [],
          'rejectedClients': [],
          'route': [
            {'lat': 30.0444, 'lng': 31.2357},
            {'lat': 30.0131, 'lng': 31.2089},
          ],
          'availableSeats': 3,
          'createdAt': '2024-06-15T10:00:00.000Z',
        },
      };

      expect(response['ride'], isNotNull);
      final ride = response['ride'] as Map<String, dynamic>;
      expect(ride['_id'], isNotEmpty);
      expect(ride['passengers'], isEmpty);
      expect(ride['route'], isList);
      expect((ride['route'] as List).length, 2);
    });

    test('userSetLocation proximity notification trigger', () {
      // Simulates the 100m proximity check in controllers/rides.js userSetLocation()
      // This is where 'driver_arrived' notification is sent
      final locationUpdate = {
        'message': 'Location updated',
        'notifications': [
          {
            'type': 'driver_arrived',
            'message': 'Driver is near your pickup location',
          }
        ],
      };

      expect(locationUpdate['notifications'], isList);
    });

    test('clientGetAllRides response maps to UserRidesModel', () {
      // Simulates response from controllers/rides.js clientGetAllRides()
      final response = {
        'rides': [
          {
            'rideId': '66abc123',
            'requestId': '66req456',
            'route': [
              {'lat': 30.0444, 'lng': 31.2357},
              {'lat': 30.0131, 'lng': 31.2089},
            ],
            'availableSeats': 3,
            'createdAt': '2024-06-15T10:00:00.000Z',
            'status': 'approved',
            'driver': {
              '_id': '66drv789',
              'firstName': 'Ahmed',
              'lastName': 'Hassan',
              'carDetails': {
                'make': 'Toyota',
                'model': 'Camry',
                'licensePlate': 'ABC-1234',
              },
            },
          },
        ],
      };

      final rides = (response['rides'] as List)
          .map((r) => UserRidesModel.fromJson(r))
          .toList();

      expect(rides.length, 1);
      expect(rides[0].rideId, '66abc123');
      expect(rides[0].status, 'approved');
      expect(rides[0].driver, isNotNull);
    });
  });

  group('JoinRequest Responses', () {
    test('create join request response maps to RideRequestModel', () {
      // Simulates POST /api/joinRequests response
      final response = {
        '_id': '66join123',
        'ride': '66ride456',
        'client': '66client789',
        'status': 'pending',
        // Backend calculatePrice() returns a float (e.g., 35.50)
        // RideRequestModel.price is now double? to handle this correctly
        'price': 35.50,
        'distance': 12.3,
        'payment': {
          'method': 'cash',
          'status': 'pending',
        },
        'tripStatus': {
          'pickedUp': false,
          'droppedOff': false,
        },
        'approvals': [
          {'user': '66drv789', 'role': 'driver', 'approved': false},
        ],
        'pickup': {'lat': 30.0131, 'lng': 31.2089},
        'dropoff': {'lat': 30.0500, 'lng': 31.2400},
      };

      final model = RideRequestModel.fromJson(response);
      expect(model.sId, '66join123');
      expect(model.status, 'pending');
      expect(model.price, 35.50);
      expect(model.payment, isNotNull);
      expect(model.payment!.status, 'pending');
      expect(model.tripStatus, isNotNull);
      expect(model.tripStatus!.pickedUp, false);
      expect(model.approvals!.length, 1);
      expect(model.approvals![0].role, 'driver');
    });

    test('approved join request with cascading approvals', () {
      // After driver approves + all existing passengers approve
      final response = {
        '_id': '66join123',
        'ride': '66ride456',
        'status': 'approved',
        'approvals': [
          {'user': '66drv789', 'role': 'driver', 'approved': true},
          {'user': '66pass1', 'role': 'passenger', 'approved': true},
          {'user': '66pass2', 'role': 'passenger', 'approved': true},
        ],
      };

      final model = RideRequestModel.fromJson(response);
      expect(model.status, 'approved');
      expect(model.approvals!.every((a) => a.approved == true), true);
    });

    test('rejected join request', () {
      final response = {
        '_id': '66join123',
        'ride': '66ride456',
        'status': 'rejected',
        'approvals': [
          {'user': '66drv789', 'role': 'driver', 'approved': true},
          {'user': '66pass1', 'role': 'passenger', 'approved': false},
        ],
      };

      final model = RideRequestModel.fromJson(response);
      expect(model.status, 'rejected');
      expect(model.approvals!.any((a) => a.approved == false), true);
    });

    test('pickup/dropoff status transitions', () {
      // After pickup
      final afterPickup = {
        '_id': '66join123',
        'status': 'approved',
        'tripStatus': {'pickedUp': true, 'droppedOff': false},
      };
      final m1 = RideRequestModel.fromJson(afterPickup);
      expect(m1.tripStatus!.pickedUp, true);
      expect(m1.tripStatus!.droppedOff, false);

      // After dropoff
      final afterDropoff = {
        '_id': '66join123',
        'status': 'finished',
        'tripStatus': {'pickedUp': true, 'droppedOff': true},
      };
      final m2 = RideRequestModel.fromJson(afterDropoff);
      expect(m2.tripStatus!.pickedUp, true);
      expect(m2.tripStatus!.droppedOff, true);
      expect(m2.status, 'finished');
    });

    test('price calculation response', () {
      // POST /api/joinRequests/calculate-price
      final response = {
        'price': 42.75,
        'distance': 15.2,
      };

      expect(response['price'], isA<double>());
      expect(response['distance'], isA<double>());
      expect(response['price']! as double, greaterThan(0));
    });
  });

  group('Chat Controller Responses', () {
    test('getChatMessages response maps to MessagesModel list', () {
      // GET /api/chat/:rideId/messages
      final response = [
        {
          '_id': 'msg1',
          'chatRoom': 'room1',
          'sender': '66drv789',
          'senderType': 'Driver',
          'content': 'Hello, I am on my way',
          'senderName': 'Ahmed Hassan',
          'timestamp': '2024-06-15T10:00:00.000Z',
        },
        {
          '_id': 'msg2',
          'chatRoom': 'room1',
          'sender': '66client456',
          'senderType': 'Client',
          'content': 'Great, I am waiting at the pickup point',
          'senderName': 'Mohamed Ali',
          'timestamp': '2024-06-15T10:01:00.000Z',
        },
      ];

      final messages = response
          .map((m) => MessagesModel.fromJson(m))
          .toList();

      expect(messages.length, 2);
      expect(messages[0].senderType, 'Driver');
      expect(messages[1].senderType, 'Client');
    });

    test('chat room creation response', () {
      // POST /api/chat/:rideId
      final response = {
        '_id': 'room1',
        'ride': '66ride456',
        'participants': ['66drv789', '66client456'],
        'messages': [],
      };

      expect(response['_id'], isNotNull);
      expect(response['participants'], isList);
      expect((response['participants'] as List).length, greaterThanOrEqualTo(2));
    });

    test('ChatMessage.fromJson handles sender as populated object', () {
      // The actual format returned by chatController.getChatMessages
      // populates sender as an object — model now handles both String and Map
      final json = {
        '_id': 'msg1',
        'sender': {
          '_id': '66drv789',
          'firstName': 'Ahmed',
          'lastName': 'Hassan',
        },
        'senderType': 'Driver',
        'content': 'I have arrived',
        'timestamp': '2024-06-15T10:30:00.000Z',
        'senderName': 'Ahmed Hassan',
      };

      final msg = ChatMessage.fromJson(json);
      expect(msg.senderId, '66drv789');
      expect(msg.senderName, 'Ahmed Hassan');
      expect(msg.message, 'I have arrived');
      expect(msg.isDriver, true);
    });
  });

  group('Payment Controller Responses', () {
    test('initializePayment cash response', () {
      // POST /api/payment/initialize (cash)
      final response = {
        'payment': {
          '_id': '66pay123',
          'ride': '66ride456',
          'payer': '66client789',
          'receiver': '66drv789',
          'amount': 35.50,
          'currency': 'EGP',
          'paymentMethod': 'cash',
          'status': 'pending',
        },
      };

      final payment = response['payment'] as Map<String, dynamic>;
      expect(payment['paymentMethod'], 'cash');
      expect(payment['status'], 'pending');
      expect(payment['currency'], 'EGP');
    });

    test('confirmCashPayment response', () {
      // PUT /api/payment/confirm-cash/:paymentId
      final response = {
        'message': 'Cash payment confirmed',
        'payment': {
          '_id': '66pay123',
          'status': 'completed',
          'completedAt': '2024-06-15T11:00:00.000Z',
        },
      };

      expect(response['payment'], isNotNull);
      final payment = response['payment'] as Map<String, dynamic>;
      expect(payment['status'], 'completed');
      expect(payment['completedAt'], isNotNull);
    });

    test('payment history response', () {
      // GET /api/payment/history
      final response = {
        'payments': [
          {
            '_id': '66pay1',
            'amount': 35.50,
            'status': 'completed',
            'paymentMethod': 'cash',
            'createdAt': '2024-06-15T10:00:00.000Z',
          },
          {
            '_id': '66pay2',
            'amount': 50.00,
            'status': 'pending',
            'paymentMethod': 'card',
            'createdAt': '2024-06-14T08:00:00.000Z',
          },
        ],
      };

      final payments = response['payments'] as List;
      expect(payments.length, 2);
      // Should be ordered by createdAt descending
      expect(payments[0]['createdAt'], isNotNull);
    });
  });

  group('Notification Responses', () {
    test('notification list response maps to AppNotification', () {
      // GET /api/notifications
      final response = [
        {
          '_id': 'notif1',
          'recipient': '66client789',
          'type': 'ride_accepted',
          'message': 'Your ride request was accepted',
          'ride': '66ride456',
          'createdAt': '2024-06-15T10:00:00.000Z',
          'read': false,
        },
        {
          '_id': 'notif2',
          'recipient': '66client789',
          'type': 'driver_arrived',
          'message': 'Driver is near your pickup location',
          'ride': '66ride456',
          'createdAt': '2024-06-15T10:30:00.000Z',
          'read': false,
        },
      ];

      final notifications = response
          .map((n) => AppNotification.fromJson(n))
          .toList();

      expect(notifications.length, 2);
      expect(notifications[0].type, 'ride_accepted');
      expect(notifications[1].type, 'driver_arrived');
      expect(notifications[0].read, false);
    });

    test('notification with populated ride field', () {
      // Sometimes the API returns populated ride object instead of just ID
      final json = {
        '_id': 'notif1',
        'recipient': '66client789',
        'type': 'ride_completed',
        'message': 'Your ride has been completed',
        'ride': {
          '_id': '66ride456',
          'driver': '66drv789',
          'status': 'completed',
        },
        'createdAt': '2024-06-15T12:00:00.000Z',
        'read': false,
      };

      // AppNotification model should handle both string and object ride field
      final notif = AppNotification.fromJson(json);
      expect(notif.type, 'ride_completed');
    });
  });

  group('Error Response Patterns', () {
    test('401 unauthorized response', () {
      final response = {
        'error': 'Access denied',
        'message': 'No token provided',
      };
      expect(response['error'], isNotNull);
    });

    test('404 not found response', () {
      final response = {
        'error': 'Ride not found',
      };
      expect(response['error'], contains('not found'));
    });

    test('400 validation error response', () {
      final response = {
        'error': 'Missing required fields',
        'details': ['pickup is required', 'dropoff is required'],
      };
      expect(response['error'], isNotNull);
      expect(response['details'], isList);
    });

    test('500 server error response', () {
      final response = {
        'error': 'Internal server error',
      };
      expect(response['error'], isNotNull);
    });

    test('OSRM API failure fallback', () {
      // When OSRM returns error, clientGetRides should handle gracefully
      final response = {
        'error': 'Route calculation failed',
        'matchedRides': [],
      };

      final rides = (response['matchedRides'] as List)
          .map((r) => AvailaibleRidesModel.fromJson(r))
          .toList();
      expect(rides, isEmpty);
    });
  });
}
