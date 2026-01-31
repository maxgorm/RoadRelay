import 'package:flutter_test/flutter_test.dart';
import 'package:drivebrief/models/notification.dart';

void main() {
  group('Sensitive Redaction Logic', () {
    final sensitiveNotification = AppNotification(
      id: 'sensitive-1',
      app: 'Chase Bank',
      sender: 'Chase',
      title: 'Account Alert',
      body: 'Transaction of \$523.45 at Amazon',
      timestamp: DateTime.now(),
      priority: 'high',
      category: 'finance',
      sensitive: true,
    );

    final normalNotification = AppNotification(
      id: 'normal-1',
      app: 'Slack',
      sender: 'Sam',
      title: 'Build complete',
      body: 'CI passed on main branch',
      timestamp: DateTime.now(),
      priority: 'medium',
      category: 'work',
      sensitive: false,
    );

    test('sensitive notification is marked as sensitive', () {
      expect(sensitiveNotification.sensitive, isTrue);
    });

    test('normal notification is not marked as sensitive', () {
      expect(normalNotification.sensitive, isFalse);
    });

    test('redacted json replaces title with app reference', () {
      final redacted = sensitiveNotification.toRedactedJson();
      expect(redacted['title'], contains(sensitiveNotification.app));
      expect(redacted['title'], equals('Sensitive alert from Chase Bank'));
    });

    test('redacted json hides original body content', () {
      final redacted = sensitiveNotification.toRedactedJson();
      expect(redacted['body'], isNot(contains('\$523.45')));
      expect(redacted['body'], isNot(contains('Amazon')));
      expect(redacted['body'], equals('[Content redacted for privacy]'));
    });

    test('redacted json hides sender information', () {
      final redacted = sensitiveNotification.toRedactedJson();
      expect(redacted['sender'], equals('Redacted'));
    });

    test('redacted json preserves non-sensitive metadata', () {
      final redacted = sensitiveNotification.toRedactedJson();
      expect(redacted['id'], equals('sensitive-1'));
      expect(redacted['app'], equals('Chase Bank'));
      expect(redacted['priority'], equals('high'));
      expect(redacted['category'], equals('finance'));
    });

    test('non-sensitive notification returns original json', () {
      final original = normalNotification.toJson();
      final redacted = normalNotification.toRedactedJson();
      
      expect(redacted['title'], equals(original['title']));
      expect(redacted['body'], equals(original['body']));
      expect(redacted['sender'], equals(original['sender']));
    });

    group('Batch redaction simulation', () {
      test('prepares mixed notifications correctly', () {
        final notifications = [
          sensitiveNotification,
          normalNotification,
          AppNotification(
            id: '2fa-1',
            app: 'Google Auth',
            sender: 'System',
            title: '2FA Code',
            body: 'Your code is 123456',
            timestamp: DateTime.now(),
            priority: 'high',
            category: 'security',
            sensitive: true,
          ),
        ];

        final preparedForSummary = notifications.map((n) {
          if (n.sensitive) {
            return n.toRedactedJson();
          }
          return n.toJson();
        }).toList();

        // Check that sensitive ones are redacted
        expect(preparedForSummary[0]['body'], equals('[Content redacted for privacy]'));
        expect(preparedForSummary[2]['body'], equals('[Content redacted for privacy]'));
        
        // Check that normal one is not redacted
        expect(preparedForSummary[1]['body'], equals('CI passed on main branch'));
      });

      test('redacted notifications include app name for context', () {
        final notifications = [
          AppNotification(
            id: 'bank-1',
            app: 'Bank of America',
            sender: 'BoA',
            title: 'Low Balance',
            body: 'Account below \$100',
            timestamp: DateTime.now(),
            priority: 'high',
            category: 'finance',
            sensitive: true,
          ),
          AppNotification(
            id: 'venmo-1',
            app: 'Venmo',
            sender: 'Venmo',
            title: 'Payment received',
            body: 'John paid you \$50',
            timestamp: DateTime.now(),
            priority: 'low',
            category: 'finance',
            sensitive: true,
          ),
        ];

        for (final n in notifications) {
          final redacted = n.toRedactedJson();
          expect(redacted['title'], contains(n.app));
        }
      });
    });

    group('Edge cases', () {
      test('handles notification with empty body', () {
        final notification = AppNotification(
          id: 'empty-1',
          app: 'Test',
          sender: 'Test',
          title: 'Empty body test',
          body: '',
          timestamp: DateTime.now(),
          priority: 'low',
          category: 'test',
          sensitive: true,
        );

        final redacted = notification.toRedactedJson();
        expect(redacted['body'], equals('[Content redacted for privacy]'));
      });

      test('handles notification with special characters in app name', () {
        final notification = AppNotification(
          id: 'special-1',
          app: 'App & Co.',
          sender: 'System',
          title: 'Alert',
          body: 'Sensitive data',
          timestamp: DateTime.now(),
          priority: 'high',
          category: 'finance',
          sensitive: true,
        );

        final redacted = notification.toRedactedJson();
        expect(redacted['title'], equals('Sensitive alert from App & Co.'));
      });
    });
  });
}
