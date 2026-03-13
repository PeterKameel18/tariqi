import 'package:flutter_test/flutter_test.dart';
import 'package:tariqi/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('fromJson parses driver message', () {
      final json = {
        '_id': 'msg1',
        'sender': 'driver123',
        'senderType': 'Driver',
        'senderName': 'Ahmed Hassan',
        'content': 'On my way!',
        'timestamp': '2026-03-09T10:00:00.000Z',
      };

      final msg = ChatMessage.fromJson(json);

      expect(msg.id, 'msg1');
      expect(msg.senderId, 'driver123');
      expect(msg.senderName, 'Ahmed Hassan');
      expect(msg.message, 'On my way!');
      expect(msg.isDriver, true);
    });

    test('fromJson parses client message', () {
      final json = {
        '_id': 'msg2',
        'sender': 'client456',
        'senderType': 'Client',
        'senderName': 'Sara Ali',
        'content': 'I am at the pickup point',
        'timestamp': '2026-03-09T10:05:00.000Z',
      };

      final msg = ChatMessage.fromJson(json);

      expect(msg.id, 'msg2');
      expect(msg.senderName, 'Sara Ali');
      expect(msg.isDriver, false);
    });

    test('fromJson defaults driver name when missing', () {
      final json = {
        '_id': 'msg3',
        'sender': 'driver123',
        'senderType': 'Driver',
        'content': 'Hello',
        'timestamp': '2026-03-09T10:00:00.000Z',
      };

      final msg = ChatMessage.fromJson(json);
      expect(msg.senderName, 'Driver');
      expect(msg.isDriver, true);
    });

    test('fromJson defaults client name when missing', () {
      final json = {
        '_id': 'msg4',
        'sender': 'client456',
        'senderType': 'Client',
        'content': 'Hi',
        'timestamp': '2026-03-09T10:00:00.000Z',
      };

      final msg = ChatMessage.fromJson(json);
      expect(msg.senderName, 'Client');
    });

    test('fromJson handles missing senderType', () {
      final json = {
        '_id': 'msg5',
        'sender': 'user123',
        'content': 'Test',
        'timestamp': '2026-03-09T10:00:00.000Z',
      };

      final msg = ChatMessage.fromJson(json);
      expect(msg.senderName, 'Client');
      expect(msg.isDriver, false);
    });

    test('fromJson uses createdAt fallback for timestamp', () {
      final json = {
        '_id': 'msg6',
        'sender': 'user123',
        'senderType': 'Client',
        'content': 'Test',
        'createdAt': '2026-03-09T10:00:00.000Z',
      };

      final msg = ChatMessage.fromJson(json);
      expect(msg.createdAt.year, 2026);
    });

    test('fromJson uses id fallback', () {
      final json = {
        'id': 'fallback-id',
        'sender': 'user123',
        'senderType': 'Client',
        'content': 'Test',
        'timestamp': '2026-03-09T10:00:00.000Z',
      };

      final msg = ChatMessage.fromJson(json);
      expect(msg.id, 'fallback-id');
    });

    test('fromJson uses content fallback from message field', () {
      final json = {
        '_id': 'msg7',
        'sender': 'user123',
        'senderType': 'Client',
        'message': 'Hello from message field',
        'timestamp': '2026-03-09T10:00:00.000Z',
      };

      final msg = ChatMessage.fromJson(json);
      expect(msg.message, 'Hello from message field');
    });

    test('fromJson handles invalid timestamp gracefully', () {
      final json = {
        '_id': 'msg8',
        'sender': 'user123',
        'senderType': 'Client',
        'content': 'Test',
        'timestamp': 'not-a-date',
      };

      final msg = ChatMessage.fromJson(json);
      expect(msg.createdAt, isNotNull);
    });
  });
}
