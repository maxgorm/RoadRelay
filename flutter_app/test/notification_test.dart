import 'package:flutter_test/flutter_test.dart';
import 'package:drivebrief/models/notification.dart';

void main() {
  group('AppNotification', () {
    group('fromJson', () {
      test('parses valid notification correctly', () {
        final json = {
          'id': 'n1',
          'app': 'Slack',
          'sender': 'Sam',
          'title': 'Build blocked',
          'body': 'CI failing on main. Can you take a look?',
          'timestamp': '2026-01-31T11:45:00-05:00',
          'priority': 'high',
          'category': 'work',
          'sensitive': false,
        };

        final notification = AppNotification.fromJson(json);

        expect(notification.id, equals('n1'));
        expect(notification.app, equals('Slack'));
        expect(notification.sender, equals('Sam'));
        expect(notification.title, equals('Build blocked'));
        expect(notification.body, equals('CI failing on main. Can you take a look?'));
        expect(notification.priority, equals('high'));
        expect(notification.category, equals('work'));
        expect(notification.sensitive, isFalse);
      });

      test('parses sensitive notification correctly', () {
        final json = {
          'id': 'n5',
          'app': 'Chase Bank',
          'sender': 'Chase',
          'title': 'Account Alert',
          'body': 'A transaction of \$523.45 was made',
          'timestamp': '2026-01-31T11:40:00-05:00',
          'priority': 'high',
          'category': 'finance',
          'sensitive': true,
        };

        final notification = AppNotification.fromJson(json);

        expect(notification.sensitive, isTrue);
        expect(notification.app, equals('Chase Bank'));
      });

      test('handles missing sensitive field as false', () {
        final json = {
          'id': 'n1',
          'app': 'Slack',
          'sender': 'Sam',
          'title': 'Test',
          'body': 'Body',
          'timestamp': '2026-01-31T11:45:00-05:00',
          'priority': 'low',
          'category': 'work',
        };

        final notification = AppNotification.fromJson(json);

        expect(notification.sensitive, isFalse);
      });

      test('parses timestamp correctly', () {
        final json = {
          'id': 'n1',
          'app': 'Test',
          'sender': 'Test',
          'title': 'Test',
          'body': 'Body',
          'timestamp': '2026-01-31T11:45:00-05:00',
          'priority': 'low',
          'category': 'test',
          'sensitive': false,
        };

        final notification = AppNotification.fromJson(json);

        expect(notification.timestamp, isA<DateTime>());
      });
    });

    group('toJson', () {
      test('serializes notification correctly', () {
        final notification = AppNotification(
          id: 'test1',
          app: 'TestApp',
          sender: 'TestSender',
          title: 'Test Title',
          body: 'Test Body',
          timestamp: DateTime.parse('2026-01-31T12:00:00Z'),
          priority: 'medium',
          category: 'test',
          sensitive: false,
        );

        final json = notification.toJson();

        expect(json['id'], equals('test1'));
        expect(json['app'], equals('TestApp'));
        expect(json['sender'], equals('TestSender'));
        expect(json['title'], equals('Test Title'));
        expect(json['body'], equals('Test Body'));
        expect(json['priority'], equals('medium'));
        expect(json['category'], equals('test'));
        expect(json['sensitive'], isFalse);
      });
    });

    group('toRedactedJson', () {
      test('returns original json for non-sensitive notification', () {
        final notification = AppNotification(
          id: 'n1',
          app: 'Slack',
          sender: 'Sam',
          title: 'Build blocked',
          body: 'CI failing',
          timestamp: DateTime.now(),
          priority: 'high',
          category: 'work',
          sensitive: false,
        );

        final json = notification.toRedactedJson();

        expect(json['body'], equals('CI failing'));
        expect(json['sender'], equals('Sam'));
      });

      test('redacts sensitive notification content', () {
        final notification = AppNotification(
          id: 'n5',
          app: 'Chase Bank',
          sender: 'Chase',
          title: 'Account Alert',
          body: 'Transaction of \$523.45',
          timestamp: DateTime.now(),
          priority: 'high',
          category: 'finance',
          sensitive: true,
        );

        final json = notification.toRedactedJson();

        expect(json['title'], equals('Sensitive alert from Chase Bank'));
        expect(json['body'], equals('[Content redacted for privacy]'));
        expect(json['sender'], equals('Redacted'));
        expect(json['app'], equals('Chase Bank'));
        expect(json['sensitive'], isTrue);
      });

      test('preserves id and category in redacted output', () {
        final notification = AppNotification(
          id: 'sensitive123',
          app: 'Bank',
          sender: 'Bank System',
          title: 'Low Balance',
          body: 'Balance is \$50',
          timestamp: DateTime.now(),
          priority: 'high',
          category: 'finance',
          sensitive: true,
        );

        final json = notification.toRedactedJson();

        expect(json['id'], equals('sensitive123'));
        expect(json['category'], equals('finance'));
        expect(json['priority'], equals('high'));
      });
    });

    group('priorityWeight', () {
      test('returns 3 for high priority', () {
        final notification = AppNotification(
          id: 'n1',
          app: 'Test',
          sender: 'Test',
          title: 'Test',
          body: 'Test',
          timestamp: DateTime.now(),
          priority: 'high',
          category: 'test',
          sensitive: false,
        );

        expect(notification.priorityWeight, equals(3));
      });

      test('returns 2 for medium priority', () {
        final notification = AppNotification(
          id: 'n1',
          app: 'Test',
          sender: 'Test',
          title: 'Test',
          body: 'Test',
          timestamp: DateTime.now(),
          priority: 'medium',
          category: 'test',
          sensitive: false,
        );

        expect(notification.priorityWeight, equals(2));
      });

      test('returns 1 for low priority', () {
        final notification = AppNotification(
          id: 'n1',
          app: 'Test',
          sender: 'Test',
          title: 'Test',
          body: 'Test',
          timestamp: DateTime.now(),
          priority: 'low',
          category: 'test',
          sensitive: false,
        );

        expect(notification.priorityWeight, equals(1));
      });

      test('returns 0 for unknown priority', () {
        final notification = AppNotification(
          id: 'n1',
          app: 'Test',
          sender: 'Test',
          title: 'Test',
          body: 'Test',
          timestamp: DateTime.now(),
          priority: 'unknown',
          category: 'test',
          sensitive: false,
        );

        expect(notification.priorityWeight, equals(0));
      });

      test('handles case-insensitive priority', () {
        final notification = AppNotification(
          id: 'n1',
          app: 'Test',
          sender: 'Test',
          title: 'Test',
          body: 'Test',
          timestamp: DateTime.now(),
          priority: 'HIGH',
          category: 'test',
          sensitive: false,
        );

        expect(notification.priorityWeight, equals(3));
      });
    });
  });
}
