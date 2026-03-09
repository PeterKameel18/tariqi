import 'package:flutter_test/flutter_test.dart';
import 'package:tariqi/models/messages_model.dart';

void main() {
  group('MessagesModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'sender': 'user123',
        'senderType': 'Driver',
        'content': 'Hello passengers!',
        'timestamp': '2026-03-09T10:00:00.000Z',
        '_id': 'msg123',
      };

      final msg = MessagesModel.fromJson(json);

      expect(msg.sender, 'user123');
      expect(msg.senderType, 'Driver');
      expect(msg.content, 'Hello passengers!');
      expect(msg.timestamp, '2026-03-09T10:00:00.000Z');
      expect(msg.sId, 'msg123');
    });

    test('fromJson handles null fields', () {
      final msg = MessagesModel.fromJson({});
      expect(msg.sender, isNull);
      expect(msg.senderType, isNull);
      expect(msg.content, isNull);
    });

    test('fromJson handles client message', () {
      final json = {
        'sender': 'client456',
        'senderType': 'Client',
        'content': 'On my way!',
        'timestamp': '2026-03-09T10:05:00.000Z',
        '_id': 'msg456',
      };

      final msg = MessagesModel.fromJson(json);
      expect(msg.senderType, 'Client');
    });
  });
}
