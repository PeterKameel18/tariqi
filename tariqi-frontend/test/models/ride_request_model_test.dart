import 'package:flutter_test/flutter_test.dart';
import 'package:tariqi/models/ride_request_model.dart';

void main() {
  group('RideRequestModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'ride': 'ride123',
        'client': 'client456',
        'status': 'pending',
        'price': 50,
        'distance': 10.5,
        'payment': {'status': 'pending', 'method': 'cash'},
        'tripStatus': {'pickedUp': false, 'droppedOff': false},
        'approvals': [
          {'user': 'driver789', 'role': 'driver', 'approved': null, '_id': 'a1'}
        ],
        '_id': 'req123',
        '__v': 0,
      };

      final model = RideRequestModel.fromJson(json);

      expect(model.ride, 'ride123');
      expect(model.client, 'client456');
      expect(model.status, 'pending');
      expect(model.price, 50);
      expect(model.distance, 10.5);
      expect(model.payment!.status, 'pending');
      expect(model.payment!.method, 'cash');
      expect(model.tripStatus!.pickedUp, false);
      expect(model.tripStatus!.droppedOff, false);
      expect(model.approvals!.length, 1);
      expect(model.approvals![0].role, 'driver');
      expect(model.sId, 'req123');
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'ride': 'ride123',
        'client': 'client456',
        'status': 'pending',
        '_id': 'req123',
      };

      final model = RideRequestModel.fromJson(json);

      expect(model.payment, isNull);
      expect(model.tripStatus, isNull);
      expect(model.approvals, isNull);
      expect(model.price, isNull);
    });

    test('fromJson handles accepted status with completed trip', () {
      final json = {
        'ride': 'ride123',
        'client': 'client456',
        'status': 'accepted',
        'tripStatus': {'pickedUp': true, 'droppedOff': true},
        'payment': {'status': 'completed', 'method': 'card'},
        '_id': 'req123',
      };

      final model = RideRequestModel.fromJson(json);

      expect(model.status, 'accepted');
      expect(model.tripStatus!.pickedUp, true);
      expect(model.tripStatus!.droppedOff, true);
      expect(model.payment!.status, 'completed');
    });
  });

  group('Payment', () {
    test('fromJson parses correctly', () {
      final payment = Payment.fromJson({'status': 'completed', 'method': 'card'});
      expect(payment.status, 'completed');
      expect(payment.method, 'card');
    });

    test('toJson outputs correctly', () {
      final payment = Payment(status: 'pending', method: 'cash');
      final json = payment.toJson();
      expect(json['status'], 'pending');
      expect(json['method'], 'cash');
    });
  });

  group('TripStatus', () {
    test('fromJson parses correctly', () {
      final status = TripStatus.fromJson({'pickedUp': true, 'droppedOff': false});
      expect(status.pickedUp, true);
      expect(status.droppedOff, false);
    });
  });

  group('Approvals', () {
    test('fromJson parses correctly', () {
      final approval = Approvals.fromJson({
        'user': 'user123',
        'role': 'driver',
        'approved': true,
        '_id': 'a1',
      });
      expect(approval.user, 'user123');
      expect(approval.role, 'driver');
      expect(approval.approved, true);
      expect(approval.sId, 'a1');
    });

    test('fromJson handles null approved', () {
      final approval = Approvals.fromJson({
        'user': 'user123',
        'role': 'client',
        'approved': null,
      });
      expect(approval.approved, isNull);
    });
  });
}
