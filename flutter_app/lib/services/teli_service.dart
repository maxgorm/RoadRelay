import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'logger_service.dart';

/// Service for interacting with Teli AI API
class TeliService {
  static const String _orgIdKey = 'teli_org_id';
  static const String _userIdKey = 'teli_user_id';
  static const String _agentIdKey = 'teli_agent_id';
  static const Duration _timeout = Duration(seconds: 30);

  String get _apiKey => dotenv.env['TELI_API_KEY'] ?? '';
  String get _baseUrl => dotenv.env['TELI_API_BASE_URL'] ?? 'https://api.teli.ai';

  TeliCredentials? _credentials;
  TeliCredentials? get credentials => _credentials;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-API-Key': _apiKey,
      };

  /// Initialize the service and load stored credentials
  Future<void> initialize() async {
    LoggerService.log('Initializing Teli service');
    await _loadStoredCredentials();
    
    if (!_credentials!.isComplete) {
      LoggerService.log('Credentials incomplete, running bootstrap');
      await bootstrap();
    } else {
      LoggerService.log('Existing credentials loaded: $_credentials');
    }
  }

  Future<void> _loadStoredCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    _credentials = TeliCredentials(
      organizationId: prefs.getString(_orgIdKey),
      userId: prefs.getString(_userIdKey),
      agentId: prefs.getString(_agentIdKey),
    );
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_credentials?.organizationId != null) {
      await prefs.setString(_orgIdKey, _credentials!.organizationId!);
    }
    if (_credentials?.userId != null) {
      await prefs.setString(_userIdKey, _credentials!.userId!);
    }
    if (_credentials?.agentId != null) {
      await prefs.setString(_agentIdKey, _credentials!.agentId!);
    }
    LoggerService.log('Credentials saved to storage');
  }

  /// Bootstrap Teli resources (idempotent)
  Future<void> bootstrap() async {
    LoggerService.log('Starting Teli bootstrap...');

    try {
      // Step 1: Create organization if needed
      if (_credentials?.organizationId == null) {
        final orgId = await _createOrganization();
        _credentials = _credentials?.copyWith(organizationId: orgId) ??
            TeliCredentials(organizationId: orgId);
      }

      // Step 2: Create user if needed
      if (_credentials?.userId == null) {
        final userId = await _createUser(_credentials!.organizationId!);
        _credentials = _credentials!.copyWith(userId: userId);
      }

      // Step 3: Create SMS agent if needed
      if (_credentials?.agentId == null) {
        final agentId = await _createAgent(
          _credentials!.organizationId!,
          _credentials!.userId!,
        );
        _credentials = _credentials!.copyWith(agentId: agentId);
      }

      await _saveCredentials();
      LoggerService.log('Bootstrap completed successfully: $_credentials');
    } catch (e) {
      LoggerService.log('Bootstrap failed: $e', isError: true);
      rethrow;
    }
  }

  Future<String> _createOrganization() async {
    LoggerService.log('Creating organization...');
    
    final response = await http
        .post(
          Uri.parse('$_baseUrl/v1/organizations'),
          headers: _headers,
          body: json.encode({
            'name': 'DriveBrief Hackathon',
            'contact_email': 'hackathon@drivebrief.app',
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final orgId = data['id']?.toString() ?? data['organization_id']?.toString();
      LoggerService.log('Organization created: $orgId');
      return orgId!;
    }
    
    throw TeliApiException('Failed to create organization', response.statusCode, response.body);
  }

  Future<String> _createUser(String orgId) async {
    LoggerService.log('Creating user for org: $orgId');
    
    final response = await http
        .post(
          Uri.parse('$_baseUrl/v1/organizations/$orgId/users'),
          headers: _headers,
          body: json.encode({
            'name': 'DriveBrief User',
            'email': 'user@drivebrief.app',
            'permission': 'admin',
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final userId = data['id']?.toString() ?? data['user_id']?.toString();
      LoggerService.log('User created: $userId');
      return userId!;
    }
    
    throw TeliApiException('Failed to create user', response.statusCode, response.body);
  }

  Future<String> _createAgent(String orgId, String userId) async {
    LoggerService.log('Creating SMS agent...');
    
    final response = await http
        .post(
          Uri.parse('$_baseUrl/v1/agents'),
          headers: _headers,
          body: json.encode({
            'agent_type': 'sms',
            'agent_name': 'DriveBrief Summarizer',
            'starting_message': 'Your DriveBrief summary is ready.',
            'prompt': _summarizeSystemPrompt,
            'organization_id': orgId,
            'user_id': userId,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final agentId = data['id']?.toString() ?? data['agent_id']?.toString();
      LoggerService.log('Agent created: $agentId');
      return agentId!;
    }
    
    throw TeliApiException('Failed to create agent', response.statusCode, response.body);
  }

  /// Summarize notifications using Teli AI
  Future<SummaryResponse> summarize(List<Map<String, dynamic>> notifications) async {
    LoggerService.log('Summarizing ${notifications.length} notifications...');
    
    final prompt = '''
$_summarizeSystemPrompt

Here are the notifications to summarize:
${json.encode(notifications)}

Output strictly valid JSON with keys: sms_text, narration_script, action_items
''';

    try {
      // Try the chat completions endpoint first
      final response = await http
          .post(
            Uri.parse('$_baseUrl/v1/chat/completions'),
            headers: _headers,
            body: json.encode({
              'model': 'teli-ai',
              'messages': [
                {'role': 'system', 'content': _summarizeSystemPrompt},
                {'role': 'user', 'content': 'Summarize these notifications:\n${json.encode(notifications)}'},
              ],
              'response_format': {'type': 'json_object'},
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        String content;
        
        // Handle different response formats
        if (data.containsKey('choices')) {
          content = data['choices'][0]['message']['content'] as String;
        } else if (data.containsKey('content')) {
          content = data['content'] as String;
        } else if (data.containsKey('response')) {
          content = data['response'] as String;
        } else {
          content = response.body;
        }

        final summaryJson = json.decode(content) as Map<String, dynamic>;
        final summary = SummaryResponse.fromJson(summaryJson);
        LoggerService.log('Summary generated: ${summary.smsText.length} chars');
        return summary;
      }
      
      // Fallback: try a simpler endpoint
      return await _summarizeFallback(notifications);
    } catch (e) {
      LoggerService.log('Primary summarize failed, trying fallback: $e', isError: true);
      return await _summarizeFallback(notifications);
    }
  }

  Future<SummaryResponse> _summarizeFallback(List<Map<String, dynamic>> notifications) async {
    LoggerService.log('Using fallback summarization...');
    
    // Try alternative endpoint
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/v1/completions'),
            headers: _headers,
            body: json.encode({
              'prompt': '''$_summarizeSystemPrompt

Notifications: ${json.encode(notifications)}

Respond with JSON only:''',
              'max_tokens': 1000,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        String content = data['text'] ?? data['content'] ?? data['response'] ?? '';
        
        // Extract JSON from response
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
        if (jsonMatch != null) {
          final summaryJson = json.decode(jsonMatch.group(0)!) as Map<String, dynamic>;
          return SummaryResponse.fromJson(summaryJson);
        }
      }
    } catch (e) {
      LoggerService.log('Fallback API also failed: $e', isError: true);
    }
    
    // Generate local summary as last resort
    return _generateLocalSummary(notifications);
  }

  SummaryResponse _generateLocalSummary(List<Map<String, dynamic>> notifications) {
    LoggerService.log('Generating local summary (API unavailable)');
    
    final highPriority = notifications.where((n) => n['priority'] == 'high').toList();
    final buffer = StringBuffer();
    
    buffer.write('DriveBrief Summary: ');
    
    if (highPriority.isNotEmpty) {
      buffer.write('${highPriority.length} urgent. ');
      for (var i = 0; i < highPriority.length && i < 3; i++) {
        final n = highPriority[i];
        if (n['sensitive'] == true) {
          buffer.write('Sensitive alert from ${n['app']}. ');
        } else {
          buffer.write('${n['app']}: ${n['title']}. ');
        }
      }
    }
    
    buffer.write('${notifications.length} total notifications.');
    
    final smsText = buffer.toString().substring(0, buffer.length > 480 ? 480 : buffer.length);
    
    final narration = StringBuffer();
    narration.writeln('Here\'s your DriveBrief summary.');
    narration.writeln('You have ${notifications.length} notifications.');
    
    if (highPriority.isNotEmpty) {
      narration.writeln('${highPriority.length} are marked as high priority.');
    }
    
    final actionItems = <String>[];
    for (final n in highPriority.take(3)) {
      if (n['sensitive'] != true) {
        actionItems.add('Check ${n['app']}: ${n['title']}');
      }
    }
    
    return SummaryResponse(
      smsText: smsText,
      narrationScript: narration.toString(),
      actionItems: actionItems,
    );
  }

  /// Send SMS via Teli API
  Future<SmsResult> sendSms(String phoneNumber, String message) async {
    LoggerService.log('Sending SMS to $phoneNumber...');
    
    // Validate phone number format (E.164)
    if (!_isValidE164(phoneNumber)) {
      return SmsResult.failure(
        error: 'Invalid phone number format. Use E.164 (e.g., +1234567890)',
        phoneNumber: phoneNumber,
      );
    }

    try {
      // Try direct SMS endpoint first
      var response = await http
          .post(
            Uri.parse('$_baseUrl/v1/sms/send'),
            headers: _headers,
            body: json.encode({
              'to': phoneNumber,
              'message': message,
              'agent_id': _credentials?.agentId,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final messageId = data['message_id']?.toString() ?? 
                          data['id']?.toString() ?? 
                          DateTime.now().millisecondsSinceEpoch.toString();
        LoggerService.log('SMS sent successfully: $messageId');
        return SmsResult.success(messageId: messageId, phoneNumber: phoneNumber);
      }

      // Try campaigns endpoint as fallback
      response = await http
          .post(
            Uri.parse('$_baseUrl/v1/campaigns'),
            headers: _headers,
            body: json.encode({
              'name': 'DriveBrief Summary ${DateTime.now().toIso8601String()}',
              'agent_id': _credentials?.agentId,
              'contacts': [
                {'phone': phoneNumber}
              ],
              'starting_message': message,
              'organization_id': _credentials?.organizationId,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final campaignId = data['campaign_id']?.toString() ?? data['id']?.toString();
        LoggerService.log('Campaign created for SMS: $campaignId');
        return SmsResult.success(messageId: campaignId ?? 'campaign-sent', phoneNumber: phoneNumber);
      }

      throw TeliApiException('SMS send failed', response.statusCode, response.body);
    } catch (e) {
      LoggerService.log('SMS send error: $e', isError: true);
      return SmsResult.failure(
        error: e.toString(),
        phoneNumber: phoneNumber,
      );
    }
  }

  bool _isValidE164(String phoneNumber) {
    // E.164 format: + followed by 1-15 digits
    final regex = RegExp(r'^\+[1-9]\d{1,14}$');
    return regex.hasMatch(phoneNumber);
  }

  static const String _summarizeSystemPrompt = '''
You are DriveBrief, an assistant that converts a list of incoming notifications
into a driving-safe briefing.

Output strictly valid JSON with keys:
- sms_text (string, max 480 characters)
- narration_script (string, suitable for 30-60 second read)
- action_items (array of strings, 0-5 items)

Rules:
1. Keep sms_text under 480 characters
2. Keep narration_script under 60 seconds when read aloud
3. If sensitive=true, redact the content and say "Sensitive alert from {app}" instead
4. Prioritize high priority notifications first
5. Group by category when possible
6. Be concise and driving-safe
''';
}

class TeliApiException implements Exception {
  final String message;
  final int statusCode;
  final String responseBody;

  TeliApiException(this.message, this.statusCode, this.responseBody);

  @override
  String toString() => 'TeliApiException: $message (HTTP $statusCode): $responseBody';
}
