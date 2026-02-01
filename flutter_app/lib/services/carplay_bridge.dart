import 'package:flutter/services.dart';
import 'simple_storage.dart';
import 'app_state.dart';
import 'logger_service.dart';

/// Bridge between Flutter and native iOS CarPlay
class CarPlayBridge {
  static const String _channelName = 'carplay_bridge';
  static const String _fallbackTriggerKey = 'carplay_trigger_timestamp';

  final MethodChannel _channel = const MethodChannel(_channelName);
  final AppState _appState;

  int? _lastProcessedTrigger;

  CarPlayBridge(this._appState);

  /// Initialize the bridge and set up method call handler
  void initialize() {
    LoggerService.log('Initializing CarPlay bridge on channel: $_channelName');

    _channel.setMethodCallHandler(_handleMethodCall);

    LoggerService.log('CarPlay bridge initialized');
  }

  /// Handle incoming method calls from native iOS
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    LoggerService.log('Received method call from native: ${call.method}');

    switch (call.method) {
      case 'sendSummaryFromCarPlay':
        return await _handleSendSummary();

      case 'askAboutNotificationsFromCarPlay':
        return await _handleAskAboutNotifications();

      case 'processVoiceQuery':
        return await _handleVoiceQuery(call.arguments);

      case 'getStatus':
        return _getStatus();

      case 'ping':
        return {'status': 'ok', 'timestamp': DateTime.now().toIso8601String()};

      // Delegate speech-related callbacks to VoiceQueryService
      case 'onSpeechResult':
      case 'onSpeechError':
        return await _appState.voiceQueryService.handleMethodCall(call);

      default:
        LoggerService.log('Unknown method: ${call.method}', isError: true);
        throw PlatformException(
          code: 'UNKNOWN_METHOD',
          message: 'Method ${call.method} not implemented',
        );
    }
  }

  Future<Map<String, dynamic>> _handleVoiceQuery(dynamic arguments) async {
    try {
      final query = arguments['query'] as String?;
      if (query == null || query.isEmpty) {
        return {'error': 'No query provided'};
      }

      LoggerService.log('Processing voice query: $query');

      // Get notifications and query Teli
      final notifications = _appState.notifications;
      final response = await _appState.teliService.queryNotifications(
        query,
        notifications.map((n) => n.toJson()).toList(),
      );

      return {'response': response};
    } catch (e) {
      LoggerService.log('Voice query error: $e', isError: true);
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _handleSendSummary() async {
    LoggerService.log('Processing sendSummaryFromCarPlay...');

    try {
      final result = await _appState.handleCarPlayTrigger();

      // Notify native of completion
      await _notifyNativeOfResult(result);

      return result;
    } catch (e) {
      LoggerService.log('CarPlay workflow failed: $e', isError: true);
      return {
        'success': false,
        'message': 'Error: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  Future<Map<String, dynamic>> _handleAskAboutNotifications() async {
    LoggerService.log('Processing askAboutNotificationsFromCarPlay...');

    try {
      // Start voice listening through the VoiceQueryService
      await _appState.voiceQueryService.startListening();

      return {
        'success': true,
        'message': 'Listening started',
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      LoggerService.log('CarPlay voice query failed: $e', isError: true);
      return {
        'success': false,
        'message': 'Error: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  Map<String, dynamic> _getStatus() {
    return {
      'initialized': _appState.isInitialized,
      'phone_number_set': _appState.phoneNumber.isNotEmpty,
      'last_summary_time': _appState.lastSummary?.generatedAt.toIso8601String(),
      'last_sms_success': _appState.lastSmsResult?.success,
    };
  }

  /// Notify native side of workflow result
  Future<void> _notifyNativeOfResult(Map<String, dynamic> result) async {
    try {
      await _channel.invokeMethod('workflowComplete', result);
      LoggerService.log('Notified native of result');
    } catch (e) {
      // Native might not have a handler for this, which is fine
      LoggerService.log('Could not notify native (may be expected): $e');
    }
  }

  /// Check for fallback trigger via UserDefaults
  /// This is used if MethodChannel doesn't work from CarPlay
  Future<void> checkFallbackTrigger() async {
    try {
      final prefs = await SimpleStorage.getInstance();
      final triggerTimestamp = prefs.getInt(_fallbackTriggerKey);

      if (triggerTimestamp != null &&
          triggerTimestamp != _lastProcessedTrigger) {
        LoggerService.log('Fallback trigger detected: $triggerTimestamp');
        _lastProcessedTrigger = triggerTimestamp;

        // Clear the trigger
        await prefs.remove(_fallbackTriggerKey);

        // Process the trigger
        await _appState.handleCarPlayTrigger();
      }
    } catch (e) {
      LoggerService.log('Error checking fallback trigger: $e', isError: true);
    }
  }

  /// Send a message to native side (for testing)
  Future<void> sendToNative(String method,
      [Map<String, dynamic>? arguments]) async {
    try {
      await _channel.invokeMethod(method, arguments);
      LoggerService.log('Sent to native: $method');
    } catch (e) {
      LoggerService.log('Failed to send to native: $e', isError: true);
    }
  }

  /// Simulate receiving an SMS notification (for testing on simulator)
  /// This triggers a local notification that appears on CarPlay
  Future<bool> simulateSmsNotification({
    required String sender,
    required String message,
  }) async {
    LoggerService.log('Simulating SMS notification from $sender');
    try {
      final result = await _channel.invokeMethod('simulateSmsNotification', {
        'sender': sender,
        'message': message,
      });
      final success = (result as Map?)?['success'] ?? false;
      LoggerService.log('Simulate notification result: $success');
      return success;
    } catch (e) {
      LoggerService.log('Failed to simulate notification: $e', isError: true);
      return false;
    }
  }

  /// Request notification permissions from native
  Future<bool> requestNotificationPermissions() async {
    try {
      final result =
          await _channel.invokeMethod('requestNotificationPermissions');
      final granted = (result as Map?)?['granted'] ?? false;
      LoggerService.log('Notification permissions: $granted');
      return granted;
    } catch (e) {
      LoggerService.log('Failed to request permissions: $e', isError: true);
      return false;
    }
  }
}
