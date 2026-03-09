import 'package:flutter_test/flutter_test.dart';
import 'package:tariqi/models/app_notification.dart';

void main() {
  group('AppNotification', () {
    test('fromJson parses complete data', () {
      final json = {
        '_id': 'notif123',
        'type': 'ride_accepted',
        'title': 'Ride Accepted',
        'message': 'Your ride has been accepted',
        'recipientId': 'user456',
        'createdAt': '2026-03-09T10:00:00.000Z',
        'read': false,
      };

      final notif = AppNotification.fromJson(json);

      expect(notif.id, 'notif123');
      expect(notif.type, 'ride_accepted');
      expect(notif.title, 'Ride Accepted');
      expect(notif.message, 'Your ride has been accepted');
      expect(notif.recipientId, 'user456');
      expect(notif.createdAt.year, 2026);
      expect(notif.read, false);
    });

    test('fromJson handles missing optional fields with defaults', () {
      final json = {
        'createdAt': '2026-03-09T10:00:00.000Z',
      };

      final notif = AppNotification.fromJson(json);

      expect(notif.id, '');
      expect(notif.type, '');
      expect(notif.title, '');
      expect(notif.message, '');
      expect(notif.recipientId, '');
      expect(notif.read, false);
    });

    test('fromJson handles read notification', () {
      final json = {
        '_id': 'notif123',
        'type': 'system_alert',
        'message': 'Test',
        'createdAt': '2026-03-09T10:00:00.000Z',
        'read': true,
      };

      final notif = AppNotification.fromJson(json);
      expect(notif.read, true);
    });
  });
}
