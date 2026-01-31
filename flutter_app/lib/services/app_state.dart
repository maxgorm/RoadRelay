import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'notification_service.dart';
import 'teli_service.dart';
import 'logger_service.dart';

/// Central app state management
class AppState extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final TeliService _teliService = TeliService();

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
    final prefs = await SharedPreferences.getInstance();
    _phoneNumber = prefs.getString('phone_number') ?? '';
    _includeSensitive = prefs.getBool('include_sensitive') ?? false;
    
    // Load last summary if available
    final lastSummaryJson = prefs.getString('last_summary');
    if (lastSummaryJson != null) {
      try {
        // We don't have json decode here but we saved the raw values
        _lastSummary = SummaryResponse(
          smsText: prefs.getString('last_sms_text') ?? '',
          narrationScript: prefs.getString('last_narration') ?? '',
          actionItems: prefs.getStringList('last_action_items') ?? [],
        );
      } catch (e) {
        LoggerService.log('Failed to load last summary: $e');
      }
    }
    
    LoggerService.log('Preferences loaded: phone=$_phoneNumber, includeSensitive=$_includeSensitive');
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phone_number', _phoneNumber);
    await prefs.setBool('include_sensitive', _includeSensitive);
    
    if (_lastSummary != null) {
      await prefs.setString('last_sms_text', _lastSummary!.smsText);
      await prefs.setString('last_narration', _lastSummary!.narrationScript);
      await prefs.setStringList('last_action_items', _lastSummary!.actionItems);
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
      final notificationsForSummary = _notificationService.prepareForSummarization(
        includeSensitive: _includeSensitive,
      );
      LoggerService.log('Prepared ${notificationsForSummary.length} notifications for summarization');

      // Step 2: Generate summary
      _lastSummary = await _teliService.summarize(notificationsForSummary);
      LoggerService.log('Summary generated: ${_lastSummary!.smsText.length} chars');
      await _savePreferences();
      notifyListeners();

      // Step 3: Send SMS
      if (_phoneNumber.isEmpty) {
        _error = 'Phone number not set';
        LoggerService.log(_error!, isError: true);
        return false;
      }

      _lastSmsResult = await _teliService.sendSms(_phoneNumber, _lastSummary!.smsText);
      
      if (_lastSmsResult!.success) {
        LoggerService.log('=== Workflow completed successfully ===');
      } else {
        LoggerService.log('SMS send failed: ${_lastSmsResult!.error}', isError: true);
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
}
