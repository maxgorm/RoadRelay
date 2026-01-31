import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drivebrief/models/notification.dart';

void main() {
  group('Summarizer Request Formatting', () {
    final testNotifications = [
      AppNotification(
        id: 'n1',
        app: 'Slack',
        sender: 'Sam',
        title: 'Build blocked',
        body: 'CI failing on main',
        timestamp: DateTime.parse('2026-01-31T11:45:00Z'),
        priority: 'high',
        category: 'work',
        sensitive: false,
      ),
      AppNotification(
        id: 'n2',
        app: 'Chase Bank',
        sender: 'Chase',
        title: 'Transaction Alert',
        body: '\$500 purchase at Store',
        timestamp: DateTime.parse('2026-01-31T11:40:00Z'),
        priority: 'high',
        category: 'finance',
        sensitive: true,
      ),
      AppNotification(
        id: 'n3',
        app: 'Calendar',
        sender: 'System',
        title: 'Meeting in 15 min',
        body: 'Team standup at 12:00',
        timestamp: DateTime.parse('2026-01-31T11:45:00Z'),
        priority: 'medium',
        category: 'calendar',
        sensitive: false,
      ),
    ];

    test('formats non-sensitive notifications with full content', () {
      final request = testNotifications
          .where((n) => !n.sensitive)
          .map((n) => n.toJson())
          .toList();

      expect(request, hasLength(2));
      expect(request[0]['body'], equals('CI failing on main'));
      expect(request[1]['body'], equals('Team standup at 12:00'));
    });

    test('formats sensitive notifications with redacted content when includeSensitive=false', () {
      final request = testNotifications.map((n) {
        if (n.sensitive) {
          return n.toRedactedJson();
        }
        return n.toJson();
      }).toList();

      expect(request, hasLength(3));
      
      // Sensitive notification should be redacted
      final sensitiveItem = request.firstWhere((n) => n['id'] == 'n2');
      expect(sensitiveItem['body'], equals('[Content redacted for privacy]'));
      expect(sensitiveItem['title'], contains('Chase Bank'));
    });

    test('formats all notifications with full content when includeSensitive=true', () {
      final request = testNotifications.map((n) => n.toJson()).toList();

      expect(request, hasLength(3));
      
      final sensitiveItem = request.firstWhere((n) => n['id'] == 'n2');
      expect(sensitiveItem['body'], equals('\$500 purchase at Store'));
    });

    test('request is valid JSON', () {
      final request = testNotifications.map((n) => n.toJson()).toList();
      
      // Should not throw
      final jsonString = json.encode(request);
      expect(jsonString, isNotEmpty);
      
      // Should be parseable
      final parsed = json.decode(jsonString);
      expect(parsed, isA<List>());
      expect(parsed, hasLength(3));
    });

    test('request preserves all required fields', () {
      final request = testNotifications.map((n) => n.toJson()).toList();
      
      for (final item in request) {
        expect(item.containsKey('id'), isTrue);
        expect(item.containsKey('app'), isTrue);
        expect(item.containsKey('sender'), isTrue);
        expect(item.containsKey('title'), isTrue);
        expect(item.containsKey('body'), isTrue);
        expect(item.containsKey('timestamp'), isTrue);
        expect(item.containsKey('priority'), isTrue);
        expect(item.containsKey('category'), isTrue);
        expect(item.containsKey('sensitive'), isTrue);
      }
    });

    test('request timestamp is ISO8601 formatted', () {
      final request = testNotifications.map((n) => n.toJson()).toList();
      
      for (final item in request) {
        final timestamp = item['timestamp'] as String;
        // Should be parseable as ISO8601
        expect(() => DateTime.parse(timestamp), returnsNormally);
      }
    });

    group('Priority sorting', () {
      test('notifications can be sorted by priority weight', () {
        final sorted = List<AppNotification>.from(testNotifications)
          ..sort((a, b) => b.priorityWeight.compareTo(a.priorityWeight));

        expect(sorted[0].priority, equals('high'));
        expect(sorted[1].priority, equals('high'));
        expect(sorted[2].priority, equals('medium'));
      });

      test('same priority notifications can be sorted by timestamp', () {
        final highPriority = testNotifications.where((n) => n.priority == 'high').toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        // n1 timestamp is later (11:45) than n2 (11:40)
        expect(highPriority[0].id, equals('n1'));
        expect(highPriority[1].id, equals('n2'));
      });
    });

    group('Category grouping', () {
      test('notifications can be grouped by category', () {
        final grouped = <String, List<AppNotification>>{};
        for (final n in testNotifications) {
          grouped.putIfAbsent(n.category, () => []).add(n);
        }

        expect(grouped.keys, containsAll(['work', 'finance', 'calendar']));
        expect(grouped['work'], hasLength(1));
        expect(grouped['finance'], hasLength(1));
        expect(grouped['calendar'], hasLength(1));
      });
    });
  });
}
