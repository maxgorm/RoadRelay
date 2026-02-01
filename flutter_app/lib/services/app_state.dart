import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'simple_storage.dart';
import '../models/models.dart';
import 'notification_service.dart';
import 'teli_service.dart';
import 'logger_service.dart';
import 'voice_query_service.dart';

/// Central app state management
class AppState extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('carplay_bridge');

  final NotificationService _notificationService = NotificationService();
  final TeliService _teliService = TeliService();
  late final VoiceQueryService _voiceQueryService;

  // State
  List<AppNotification> _notifications = [];
  SummaryResponse? _lastSummary;
  SmsResult? _lastSmsResult;
  String _phoneNumber = '';
  bool _includeSensitive = false;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  // Getters
  List<AppNotification> get notifications => _notifications;
  SummaryResponse? get lastSummary => _lastSummary;
  SmsResult? get lastSmsResult => _lastSmsResult;
  String get phoneNumber => _phoneNumber;
  bool get includeSensitive => _includeSensitive;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;
  NotificationService get notificationService => _notificationService;
  TeliService get teliService => _teliService;
  VoiceQueryService get voiceQueryService => _voiceQueryService;

  /// Initialize the app state
  Future<void> initialize() async {
    if (_isInitialized) return;

    LoggerService.log('Initializing AppState...');
    _setLoading(true);

    try {
      // Load saved preferences
      await _loadPreferences();

      // Load notifications from JSON
      _notifications = await _notificationService.loadNotifications();

      // Initialize Teli service (bootstrap if needed)
      await _teliService.initialize();

      // Initialize voice query service
      _voiceQueryService = VoiceQueryService(
        teliService: _teliService,
        notificationService: _notificationService,
      );

      _isInitialized = true;
      LoggerService.log('AppState initialized successfully');
    } catch (e) {
      _error = 'Initialization failed: $e';
      LoggerService.log(_error!, isError: true);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SimpleStorage.getInstance();
    _phoneNumber = prefs.getString('phone_number') ?? '';
    _includeSensitive = prefs.getBool('include_sensitive') ?? false;

    // Load last summary if available
    final lastSmsText = prefs.getString('last_sms_text');
    if (lastSmsText != null) {
      try {
        _lastSummary = SummaryResponse(
          smsText: lastSmsText,
          narrationScript: prefs.getString('last_narration') ?? '',
          actionItems: [],
        );
      } catch (e) {
        LoggerService.log('Failed to load last summary: $e');
      }
    }

    LoggerService.log(
        'Preferences loaded: phone=$_phoneNumber, includeSensitive=$_includeSensitive');

    // Notify listeners so UI updates with loaded phone number
    notifyListeners();
  }

  Future<void> _savePreferences() async {
    final prefs = await SimpleStorage.getInstance();
    await prefs.setString('phone_number', _phoneNumber);
    await prefs.setBool('include_sensitive', _includeSensitive);

    if (_lastSummary != null) {
      await prefs.setString('last_sms_text', _lastSummary!.smsText);
      await prefs.setString('last_narration', _lastSummary!.narrationScript);
    }
  }

  /// Set phone number
  void setPhoneNumber(String number) {
    _phoneNumber = number;
    _savePreferences();
    notifyListeners();
  }

  /// Toggle include sensitive content
  void setIncludeSensitive(bool value) {
    _includeSensitive = value;
    _savePreferences();
    LoggerService.log('Include sensitive: $value');
    notifyListeners();
  }

  /// Run the full workflow: summarize and send SMS
  Future<bool> runSummaryWorkflow() async {
    LoggerService.log('=== Starting Summary Workflow ===');
    _clearError();
    _setLoading(true);

    try {
      // Step 1: Prepare notifications
      final notificationsForSummary =
          _notificationService.prepareForSummarization(
        includeSensitive: _includeSensitive,
      );
      LoggerService.log(
          'Prepared ${notificationsForSummary.length} notifications for summarization');

      // Step 2: Generate summary
      _lastSummary = await _teliService.summarize(notificationsForSummary);
      LoggerService.log(
          'Summary generated: ${_lastSummary!.smsText.length} chars');
      await _savePreferences();
      notifyListeners();

      // Step 3: Send SMS
      if (_phoneNumber.isEmpty) {
        _error = 'Phone number not set';
        LoggerService.log(_error!, isError: true);
        return false;
      }

      _lastSmsResult =
          await _teliService.sendSms(_phoneNumber, _lastSummary!.smsText);

      if (_lastSmsResult!.success) {
        LoggerService.log('=== Workflow completed successfully ===');

        // Simulate receiving the SMS as a local notification (for simulator testing)
        await _simulateSmsNotification(_lastSummary!.smsText);
      } else {
        LoggerService.log('SMS send failed: ${_lastSmsResult!.error}',
            isError: true);
      }

      notifyListeners();
      return _lastSmsResult!.success;
    } catch (e) {
      _error = 'Workflow failed: $e';
      LoggerService.log(_error!, isError: true);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Called from CarPlay via MethodChannel
  Future<Map<String, dynamic>> handleCarPlayTrigger() async {
    LoggerService.log('CarPlay trigger received');

    final success = await runSummaryWorkflow();

    return {
      'success': success,
      'message': success
          ? 'Summary sent to $_phoneNumber'
          : (_error ?? 'Unknown error'),
      'timestamp': DateTime.now().toIso8601String(),
      'summary_text': _lastSummary?.smsText ?? '',
    };
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void clearError() => _clearError();

  /// Reload notifications
  Future<void> reloadNotifications() async {
    LoggerService.log('Reloading notifications...');
    _setLoading(true);
    try {
      _notifications = await _notificationService.loadNotifications();
      LoggerService.log('Notifications reloaded: ${_notifications.length}');
    } catch (e) {
      _error = 'Failed to reload: $e';
      LoggerService.log(_error!, isError: true);
    } finally {
      _setLoading(false);
    }
  }

  /// Simulate receiving SMS as a local notification (for simulator testing)
  Future<void> _simulateSmsNotification(String message) async {
    try {
      LoggerService.log('Simulating SMS notification for CarPlay...');
      await _channel.invokeMethod('simulateSmsNotification', {
        'sender': 'RoadRelay',
        'message': message,
      });
      LoggerService.log('SMS notification simulated');
    } catch (e) {
      LoggerService.log('Failed to simulate notification: $e', isError: true);
    }
  }
}
