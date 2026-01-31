import 'package:flutter_test/flutter_test.dart';
import 'package:drivebrief/models/summary_response.dart';

void main() {
  group('SummaryResponse', () {
    group('fromJson', () {
      test('parses valid summary response', () {
        final json = {
          'sms_text': 'Your DriveBrief summary: 5 urgent notifications.',
          'narration_script': 'Here is your driving briefing...',
          'action_items': ['Check Slack', 'Review email', 'Call mom'],
        };

        final response = SummaryResponse.fromJson(json);

        expect(response.smsText, equals('Your DriveBrief summary: 5 urgent notifications.'));
        expect(response.narrationScript, equals('Here is your driving briefing...'));
        expect(response.actionItems, hasLength(3));
        expect(response.actionItems[0], equals('Check Slack'));
      });

      test('handles missing sms_text', () {
        final json = {
          'narration_script': 'Narration',
          'action_items': [],
        };

        final response = SummaryResponse.fromJson(json);

        expect(response.smsText, isEmpty);
      });

      test('handles missing narration_script', () {
        final json = {
          'sms_text': 'SMS text',
          'action_items': [],
        };

        final response = SummaryResponse.fromJson(json);

        expect(response.narrationScript, isEmpty);
      });

      test('handles missing action_items', () {
        final json = {
          'sms_text': 'SMS text',
          'narration_script': 'Narration',
        };

        final response = SummaryResponse.fromJson(json);

        expect(response.actionItems, isEmpty);
      });

      test('handles null action_items', () {
        final json = {
          'sms_text': 'SMS text',
          'narration_script': 'Narration',
          'action_items': null,
        };

        final response = SummaryResponse.fromJson(json);

        expect(response.actionItems, isEmpty);
      });
    });

    group('toJson', () {
      test('serializes correctly', () {
        final response = SummaryResponse(
          smsText: 'Test SMS',
          narrationScript: 'Test narration',
          actionItems: ['Item 1', 'Item 2'],
        );

        final json = response.toJson();

        expect(json['sms_text'], equals('Test SMS'));
        expect(json['narration_script'], equals('Test narration'));
        expect(json['action_items'], equals(['Item 1', 'Item 2']));
        expect(json['generated_at'], isNotNull);
      });
    });

    group('isValid', () {
      test('returns true for valid summary', () {
        final response = SummaryResponse(
          smsText: 'Valid SMS under 480 chars',
          narrationScript: 'Valid narration script',
          actionItems: [],
        );

        expect(response.isValid, isTrue);
      });

      test('returns false for empty sms_text', () {
        final response = SummaryResponse(
          smsText: '',
          narrationScript: 'Valid narration',
          actionItems: [],
        );

        expect(response.isValid, isFalse);
      });

      test('returns false for empty narration_script', () {
        final response = SummaryResponse(
          smsText: 'Valid SMS',
          narrationScript: '',
          actionItems: [],
        );

        expect(response.isValid, isFalse);
      });

      test('returns false for sms_text over 480 chars', () {
        final longText = 'a' * 481;
        final response = SummaryResponse(
          smsText: longText,
          narrationScript: 'Valid narration',
          actionItems: [],
        );

        expect(response.isValid, isFalse);
      });

      test('returns true for sms_text at exactly 480 chars', () {
        final exactText = 'a' * 480;
        final response = SummaryResponse(
          smsText: exactText,
          narrationScript: 'Valid narration',
          actionItems: [],
        );

        expect(response.isValid, isTrue);
      });
    });

    group('generatedAt', () {
      test('sets current time if not provided', () {
        final before = DateTime.now();
        final response = SummaryResponse(
          smsText: 'Test',
          narrationScript: 'Test',
          actionItems: [],
        );
        final after = DateTime.now();

        expect(response.generatedAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
        expect(response.generatedAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
      });

      test('uses provided time', () {
        final customTime = DateTime(2026, 1, 15, 10, 30);
        final response = SummaryResponse(
          smsText: 'Test',
          narrationScript: 'Test',
          actionItems: [],
          generatedAt: customTime,
        );

        expect(response.generatedAt, equals(customTime));
      });
    });
  });
}
