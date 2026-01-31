/// Response from the summarizer containing SMS text, narration, and action items
class SummaryResponse {
  final String smsText;
  final String narrationScript;
  final List<String> actionItems;
  final DateTime generatedAt;

  SummaryResponse({
    required this.smsText,
    required this.narrationScript,
    required this.actionItems,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  factory SummaryResponse.fromJson(Map<String, dynamic> json) {
    return SummaryResponse(
      smsText: json['sms_text'] as String? ?? '',
      narrationScript: json['narration_script'] as String? ?? '',
      actionItems: (json['action_items'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sms_text': smsText,
      'narration_script': narrationScript,
      'action_items': actionItems,
      'generated_at': generatedAt.toIso8601String(),
    };
  }

  /// Validates the summary meets requirements
  bool get isValid {
    return smsText.isNotEmpty && 
           smsText.length <= 480 && 
           narrationScript.isNotEmpty;
  }

  @override
  String toString() {
    return 'SummaryResponse(smsText: ${smsText.length} chars, actionItems: ${actionItems.length})';
  }
}
