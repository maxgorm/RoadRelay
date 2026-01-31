/// Represents a notification from a simulated source
class AppNotification {
  final String id;
  final String app;
  final String sender;
  final String title;
  final String body;
  final DateTime timestamp;
  final String priority;
  final String category;
  final bool sensitive;

  AppNotification({
    required this.id,
    required this.app,
    required this.sender,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.priority,
    required this.category,
    required this.sensitive,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      app: json['app'] as String,
      sender: json['sender'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      priority: json['priority'] as String,
      category: json['category'] as String,
      sensitive: json['sensitive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'app': app,
      'sender': sender,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'priority': priority,
      'category': category,
      'sensitive': sensitive,
    };
  }

  /// Returns a redacted version for sensitive notifications
  Map<String, dynamic> toRedactedJson() {
    if (sensitive) {
      return {
        'id': id,
        'app': app,
        'sender': 'Redacted',
        'title': 'Sensitive alert from $app',
        'body': '[Content redacted for privacy]',
        'timestamp': timestamp.toIso8601String(),
        'priority': priority,
        'category': category,
        'sensitive': true,
      };
    }
    return toJson();
  }

  /// Priority weight for sorting (higher = more important)
  int get priorityWeight {
    switch (priority.toLowerCase()) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  @override
  String toString() {
    return 'AppNotification(id: $id, app: $app, title: $title, sensitive: $sensitive)';
  }
}
