import 'package:flutter_test/flutter_test.dart';
import 'package:tariqi/models/notification_model.dart';

void main() {
  group('NotificationModel', () {
    group('fromJson', () {
      test('parses complete data correctly', () {
        final json = {
          'title': 'Ride Accepted',
          'body': 'Your ride request has been accepted by the driver',
          'type': 'ride_accepted',
          'isRead': false,
        };
        final notif = NotificationModel.fromJson(json);
        expect(notif.title, 'Ride Accepted');
        expect(notif.body, 'Your ride request has been accepted by the driver');
        expect(notif.type, 'ride_accepted');
        expect(notif.isRead, false);
      });

      test('parses read notification', () {
        final json = {
          'title': 'Old Notification',
          'body': 'This was read',
          'type': 'system_alert',
          'isRead': true,
        };
        final notif = NotificationModel.fromJson(json);
        expect(notif.isRead, true);
      });

      // NotificationModel.fromJson now handles null fields with defaults
      test('handles null title gracefully', () {
        final json = {
          'title': null,
          'body': 'test',
          'type': 'test',
          'isRead': false,
        };
        final notif = NotificationModel.fromJson(json);
        expect(notif.title, 'Notification');
        expect(notif.body, 'test');
      });

      test('handles null body gracefully', () {
        final json = {
          'title': 'test',
          'body': null,
          'type': 'test',
          'isRead': false,
        };
        final notif = NotificationModel.fromJson(json);
        expect(notif.body, '');
      });

      test('handles null type gracefully', () {
        final json = {
          'title': 'test',
          'body': 'test',
          'type': null,
          'isRead': false,
        };
        final notif = NotificationModel.fromJson(json);
        expect(notif.type, 'system_alert');
      });

      test('handles null isRead gracefully', () {
        final json = {
          'title': 'test',
          'body': 'test',
          'type': 'test',
          'isRead': null,
        };
        final notif = NotificationModel.fromJson(json);
        expect(notif.isRead, false);
      });

      test('handles missing fields gracefully', () {
        final json = <String, dynamic>{};
        final notif = NotificationModel.fromJson(json);
        expect(notif.title, 'Notification');
        expect(notif.body, '');
        expect(notif.type, 'system_alert');
        expect(notif.isRead, false);
      });

      test('maps backend message field to body', () {
        final json = {
          'type': 'ride_accepted',
          'message': 'Your ride request has been accepted.',
          'isRead': false,
        };
        final notif = NotificationModel.fromJson(json);
        expect(notif.title, 'Request Accepted');
        expect(notif.body, 'Your ride request has been accepted.');
      });

      test('handles all notification types from backend', () {
        // Backend defines these notification type enum values
        final types = [
          'ride_request',
          'ride_accepted',
          'ride_rejected',
          'ride_cancelled',
          'driver_arrived',
          'ride_started',
          'ride_completed',
          'payment_received',
          'payment_sent',
          'new_message',
          'system_alert',
          'passenger_joined',
          'passenger_left',
          'driver_location_update',
          'passenger_approval_request',
          'passenger_approved',
          'passenger_rejected',
          'passenger_picked_up',
          'passenger_dropped_off',
        ];

        for (final type in types) {
          final json = {
            'title': 'Test',
            'body': 'Test body',
            'type': type,
            'isRead': false,
          };
          final notif = NotificationModel.fromJson(json);
          expect(notif.type, type);
        }
      });

      test('handles unicode/Arabic text in title and body', () {
        final json = {
          'title': 'تم قبول رحلتك',
          'body': 'تم قبول طلب الانضمام الخاص بك',
          'type': 'ride_accepted',
          'isRead': false,
        };
        final notif = NotificationModel.fromJson(json);
        expect(notif.title, 'تم قبول رحلتك');
        expect(notif.body, 'تم قبول طلب الانضمام الخاص بك');
      });

      test('handles very long body text', () {
        final longBody = 'A' * 10000;
        final json = {
          'title': 'Test',
          'body': longBody,
          'type': 'system_alert',
          'isRead': false,
        };
        final notif = NotificationModel.fromJson(json);
        expect(notif.body.length, 10000);
      });

      test('handles empty strings', () {
        final json = {
          'title': '',
          'body': '',
          'type': '',
          'isRead': false,
        };
        final notif = NotificationModel.fromJson(json);
        expect(notif.title, '');
        expect(notif.body, '');
        expect(notif.type, '');
      });
    });

    test('fields are mutable', () {
      final json = {
        'title': 'Original',
        'body': 'Original body',
        'type': 'test',
        'isRead': false,
      };
      final notif = NotificationModel.fromJson(json);
      notif.isRead = true;
      notif.title = 'Modified';
      expect(notif.isRead, true);
      expect(notif.title, 'Modified');
    });
  });
}
