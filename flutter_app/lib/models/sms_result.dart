/// Represents the result of sending an SMS
class SmsResult {
  final bool success;
  final String? messageId;
  final String? error;
  final DateTime timestamp;
  final String phoneNumber;

  SmsResult({
    required this.success,
    this.messageId,
    this.error,
    DateTime? timestamp,
    required this.phoneNumber,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SmsResult.success({
    required String messageId,
    required String phoneNumber,
  }) {
    return SmsResult(
      success: true,
      messageId: messageId,
      phoneNumber: phoneNumber,
    );
  }

  factory SmsResult.failure({
    required String error,
    required String phoneNumber,
  }) {
    return SmsResult(
      success: false,
      error: error,
      phoneNumber: phoneNumber,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message_id': messageId,
      'error': error,
      'timestamp': timestamp.toIso8601String(),
      'phone_number': phoneNumber,
    };
  }

  @override
  String toString() {
    if (success) {
      return 'SMS sent successfully (ID: $messageId)';
    }
    return 'SMS failed: $error';
  }
}
