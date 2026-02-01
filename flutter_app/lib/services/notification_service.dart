import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../models/notification.dart';
import 'logger_service.dart';

/// Service for loading and managing simulated notifications
class NotificationService {
  static const String _assetPath = 'assets/notifications.json';

  List<AppNotification> _notifications = [];
  bool _isLoaded = false;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  bool get isLoaded => _isLoaded;

  /// Loads notifications from the JSON asset file
  Future<List<AppNotification>> loadNotifications() async {
    LoggerService.log('Loading notifications from $_assetPath');

    try {
      final jsonString = await rootBundle.loadString(_assetPath);
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

      _notifications = jsonList
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();

      // Sort by priority (high first) then by timestamp (recent first)
      _notifications.sort((a, b) {
        final priorityCompare = b.priorityWeight.compareTo(a.priorityWeight);
        if (priorityCompare != 0) return priorityCompare;
        return b.timestamp.compareTo(a.timestamp);
      });

      _isLoaded = true;
      LoggerService.log(
          'Loaded ${_notifications.length} notifications successfully');

      return _notifications;
    } catch (e) {
      LoggerService.log('Error loading notifications: $e', isError: true);
      rethrow;
    }
  }

  /// Returns notifications grouped by category
  Map<String, List<AppNotification>> getGroupedByCategory() {
    final grouped = <String, List<AppNotification>>{};

    for (final notification in _notifications) {
      grouped.putIfAbsent(notification.category, () => []).add(notification);
    }

    return grouped;
  }

  /// Returns notifications filtered by priority
  List<AppNotification> getByPriority(String priority) {
    return _notifications
        .where((n) => n.priority.toLowerCase() == priority.toLowerCase())
        .toList();
  }

  /// Prepares notifications for summarization, handling sensitive content
  /// Uses ALL notifications shuffled for variety in presentation order
  List<Map<String, dynamic>> prepareForSummarization({
    required bool includeSensitive,
  }) {
    // Create a shuffled copy of ALL notifications for variety in order
    final shuffled = List<AppNotification>.from(_notifications);
    shuffled.shuffle(Random());

    // Sort by priority so high priority items come first
    shuffled.sort((a, b) => b.priorityWeight.compareTo(a.priorityWeight));

    LoggerService.log(
        'Preparing all ${shuffled.length} notifications for summary');

    return shuffled.map((n) {
      if (n.sensitive && !includeSensitive) {
        return n.toRedactedJson();
      }
      return n.toJson();
    }).toList();
  }

  /// Returns count statistics
  Map<String, int> getStats() {
    return {
      'total': _notifications.length,
      'high': getByPriority('high').length,
      'medium': getByPriority('medium').length,
      'low': getByPriority('low').length,
      'sensitive': _notifications.where((n) => n.sensitive).length,
    };
  }
}
