import 'package:intl/intl.dart';

/// Centralized logging service for debugging
class LoggerService {
  static final List<LogEntry> _logs = [];
  static const int _maxLogs = 500;

  static List<LogEntry> get logs => List.unmodifiable(_logs);

  static void log(String message, {bool isError = false}) {
    final entry = LogEntry(
      message: message,
      timestamp: DateTime.now(),
      isError: isError,
    );

    _logs.add(entry);

    // Trim old logs
    if (_logs.length > _maxLogs) {
      _logs.removeRange(0, _logs.length - _maxLogs);
    }

    // Also print to console for debugging
    final prefix = isError ? '❌ ERROR' : '📝 LOG';
    print('$prefix [${entry.formattedTime}]: $message');
  }

  static void clear() {
    _logs.clear();
    log('Logs cleared');
  }

  static String exportLogs() {
    final buffer = StringBuffer();
    buffer.writeln('=== RoadRelay Debug Logs ===');
    buffer.writeln('Exported: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total entries: ${_logs.length}');
    buffer.writeln('');

    for (final entry in _logs) {
      final prefix = entry.isError ? '[ERROR]' : '[INFO]';
      buffer.writeln('$prefix ${entry.formattedTime}: ${entry.message}');
    }

    return buffer.toString();
  }
}

class LogEntry {
  final String message;
  final DateTime timestamp;
  final bool isError;

  LogEntry({
    required this.message,
    required this.timestamp,
    this.isError = false,
  });

  String get formattedTime => DateFormat('HH:mm:ss.SSS').format(timestamp);

  String get formattedDateTime =>
      DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);
}
