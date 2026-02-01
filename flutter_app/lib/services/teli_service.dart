import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'simple_storage.dart';
import '../models/models.dart';
import 'logger_service.dart';

/// Service for interacting with Teli AI API
class TeliService {
  static const String _orgIdKey = 'teli_org_id';
  static const String _userIdKey = 'teli_user_id';
  static const String _agentIdKey = 'teli_agent_id';
  static const Duration _timeout = Duration(seconds: 30);

  String get _apiKey => dotenv.env['TELI_API_KEY'] ?? '';
  String get _baseUrl =>
      dotenv.env['TELI_API_BASE_URL'] ??
      'https://teli-hackathon--transfer-message-service-fastapi-app.modal.run';
  String get _smsNumber => dotenv.env['TELI_SMS_NUMBER'] ?? '+13135727768';

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
    final prefs = await SimpleStorage.getInstance();
    _credentials = TeliCredentials(
      organizationId: prefs.getString(_orgIdKey),
      userId: prefs.getString(_userIdKey),
      agentId: prefs.getString(_agentIdKey),
    );
  }

  Future<void> _saveCredentials() async {
    final prefs = await SimpleStorage.getInstance();
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
      // Use the pre-created RoadRelay organization (set up by Teli with SMS enabled)
      // Use unique_id format (not UUID)
      String orgId =
          _credentials?.organizationId ?? '1769898908954x364004182675685395';
      _credentials = TeliCredentials(organizationId: orgId);
      LoggerService.log('Using RoadRelay organization: $orgId');

      // Step 2: Use pre-created user or create if needed
      String? userId =
          _credentials?.userId ?? '1769902810719x877832955582537843';
      _credentials = _credentials!.copyWith(userId: userId);
      LoggerService.log('Using user: $userId');

      // Step 3: Use pre-created SMS agent or create if needed
      String? agentId =
          _credentials?.agentId ?? '1769902817780x666349606555853804';
      _credentials = _credentials!.copyWith(agentId: agentId);
      LoggerService.log('Using agent: $agentId');

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
            'name': 'RoadRelay Hackathon',
            'contact_email': 'hackathon@roadrelay.app',
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      LoggerService.log('Organization response: $data');

      // ID can be in nested 'organization' object or at root level
      final org = data['organization'] as Map<String, dynamic>?;
      final orgId = org?['unique_id']?.toString() ??
          org?['id']?.toString() ??
          data['unique_id']?.toString() ??
          data['organization_id']?.toString() ??
          data['id']?.toString();
      if (orgId == null) {
        throw TeliApiException('Organization created but no ID returned',
            response.statusCode, response.body);
      }
      LoggerService.log('Organization created: $orgId');
      return orgId;
    }

    throw TeliApiException(
        'Failed to create organization', response.statusCode, response.body);
  }

  Future<String> _createUser(String orgId) async {
    LoggerService.log('Creating user for org: $orgId');

    // Generate unique email to avoid duplicate key errors
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniqueEmail = 'user-$timestamp@roadrelay.app';

    final response = await http
        .post(
          Uri.parse('$_baseUrl/v1/organizations/$orgId/users'),
          headers: _headers,
          body: json.encode({
            'name': 'RoadRelay User',
            'email': uniqueEmail,
            'permission': 'admin',
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      LoggerService.log('User response: $data');

      // ID can be in nested 'user' object or at root level
      final user = data['user'] as Map<String, dynamic>?;
      final userId = user?['unique_id']?.toString() ??
          user?['id']?.toString() ??
          data['unique_id']?.toString() ??
          data['user_id']?.toString() ??
          data['id']?.toString();
      if (userId == null) {
        throw TeliApiException('User created but no ID returned',
            response.statusCode, response.body);
      }
      LoggerService.log('User created: $userId');
      return userId;
    }

    throw TeliApiException(
        'Failed to create user', response.statusCode, response.body);
  }

  Future<String> _createAgent(String orgId, String userId) async {
    LoggerService.log('Creating SMS agent...');

    final response = await http
        .post(
          Uri.parse('$_baseUrl/v1/agents'),
          headers: _headers,
          body: json.encode({
            'agent_type': 'sms',
            'agent_name': 'RoadRelay Summarizer',
            'starting_message': 'Your RoadRelay summary is ready.',
            'prompt': _summarizeSystemPrompt,
            'organization_id': orgId,
            'user_id': userId,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      LoggerService.log('Agent response: $data');

      // ID can be in nested 'agent' object or at root level
      final agent = data['agent'] as Map<String, dynamic>?;
      final agentId = data['agent_id']?.toString() ??
          agent?['agent_id']?.toString() ??
          agent?['unique_id']?.toString() ??
          agent?['id']?.toString() ??
          data['unique_id']?.toString() ??
          data['id']?.toString();
      if (agentId == null) {
        throw TeliApiException('Agent created but no ID returned',
            response.statusCode, response.body);
      }
      LoggerService.log('Agent created: $agentId');
      return agentId;
    }

    throw TeliApiException(
        'Failed to create agent', response.statusCode, response.body);
  }

  /// Summarize notifications using Teli AI
  Future<SummaryResponse> summarize(
      List<Map<String, dynamic>> notifications) async {
    LoggerService.log('Summarizing ${notifications.length} notifications...');

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
                {
                  'role': 'user',
                  'content':
                      'Summarize these notifications:\n${json.encode(notifications)}'
                },
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
      LoggerService.log('Primary summarize failed, trying fallback: $e',
          isError: true);
      return await _summarizeFallback(notifications);
    }
  }

  /// Query notifications with a specific question
  Future<String> queryNotifications(
      String userQuery, List<Map<String, dynamic>> notifications) async {
    LoggerService.log('Querying notifications: $userQuery');

    // Build context from notifications
    final notificationContext = notifications.isNotEmpty
        ? notifications
            .map((n) =>
                '- ${n['app'] ?? 'Unknown'}: ${n['title'] ?? ''} - ${n['body'] ?? ''}')
            .join('\n')
        : 'No notifications available';

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/v1/chat/completions'),
            headers: _headers,
            body: json.encode({
              'model': 'teli-ai',
              'messages': [
                {
                  'role': 'system',
                  'content':
                      '''You are RoadRelay, a helpful driving assistant. The user is asking about their notifications while driving.

Here are the user's current notifications:
$notificationContext

Answer their question conversationally and concisely based on these notifications. Be natural and friendly. If they ask about something not in the notifications, let them know you don't see a notification about that.'''
                },
                {
                  'role': 'user',
                  'content': userQuery,
                },
              ],
            }),
          )
          .timeout(_timeout);

      LoggerService.log('Query API response status: ${response.statusCode}');
      LoggerService.log('Query API response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        // Extract content
        String content = '';
        if (data.containsKey('choices')) {
          content = data['choices'][0]['message']['content'] as String;
        } else if (data.containsKey('content')) {
          content = data['content'] as String;
        } else if (data.containsKey('response')) {
          content = data['response'] as String;
        }

        LoggerService.log('Query response: $content');
        return content.isNotEmpty
            ? content
            : 'Sorry, I couldn\'t find an answer to that.';
      }

      LoggerService.log('Query failed with status: ${response.statusCode}',
          isError: true);
      return 'Sorry, I had trouble processing that question.';
    } catch (e) {
      LoggerService.log('Query failed: $e', isError: true);
      return 'Sorry, I encountered an error processing your question.';
    }
  }

  Future<SummaryResponse> _summarizeFallback(
      List<Map<String, dynamic>> notifications) async {
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
        String content =
            data['text'] ?? data['content'] ?? data['response'] ?? '';

        // Extract JSON from response
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
        if (jsonMatch != null) {
          final summaryJson =
              json.decode(jsonMatch.group(0)!) as Map<String, dynamic>;
          return SummaryResponse.fromJson(summaryJson);
        }
      }
    } catch (e) {
      LoggerService.log('Fallback API also failed: $e', isError: true);
    }

    // Generate local summary as last resort
    return _generateLocalSummary(notifications);
  }

  SummaryResponse _generateLocalSummary(
      List<Map<String, dynamic>> notifications) {
    LoggerService.log('Generating local summary (API unavailable)');

    final highPriority =
        notifications.where((n) => n['priority'] == 'high').toList();
    final mediumPriority =
        notifications.where((n) => n['priority'] == 'medium').toList();
    final buffer = StringBuffer();

    // Start with a friendly greeting
    buffer.write('Hey! Here\'s your RoadRelay update: ');

    // Describe urgent items conversationally
    if (highPriority.isNotEmpty) {
      buffer.write(
          'You have ${highPriority.length} important ${highPriority.length == 1 ? 'thing' : 'things'} to know about. ');
      for (var i = 0; i < highPriority.length && i < 3; i++) {
        final n = highPriority[i];
        if (n['sensitive'] == true) {
          buffer.write('There\'s a private alert from ${n['app']}. ');
        } else {
          final app = n['app']?.toString() ?? 'an app';
          final title = n['title']?.toString() ?? '';
          if (app.toLowerCase().contains('calendar') ||
              app.toLowerCase().contains('outlook')) {
            buffer.write('Heads up, you have "$title" coming up. ');
          } else if (app.toLowerCase().contains('slack') ||
              app.toLowerCase().contains('teams')) {
            buffer.write('Your team on $app says: "$title". ');
          } else if (app.toLowerCase().contains('maps') ||
              app.toLowerCase().contains('waze')) {
            buffer.write('Traffic update: $title. ');
          } else {
            buffer.write('From $app: $title. ');
          }
        }
      }
    }

    // Add medium priority context
    if (mediumPriority.isNotEmpty && buffer.length < 350) {
      buffer.write('Also, ');
      final n = mediumPriority.first;
      if (n['sensitive'] != true) {
        buffer.write('${n['app']} mentioned: ${n['title']}. ');
      }
    }

    // Friendly closing
    final remaining = notifications.length - highPriority.length.clamp(0, 3);
    if (remaining > 0) {
      buffer.write(
          'Plus $remaining more ${remaining == 1 ? 'notification' : 'notifications'} when you\'re ready.');
    }

    final smsText = buffer.toString().length > 480
        ? buffer.toString().substring(0, 477) + '...'
        : buffer.toString();

    final narration = StringBuffer();
    narration.writeln('Hey there! Here\'s your RoadRelay summary.');
    narration.writeln(
        'You have ${notifications.length} notifications waiting for you.');

    if (highPriority.isNotEmpty) {
      narration
          .writeln('${highPriority.length} of them need your attention soon.');
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

  /// Send SMS via Teli API using campaigns endpoint
  Future<SmsResult> sendSms(String phoneNumber, String message) async {
    LoggerService.log('Sending SMS to $phoneNumber...');
    LoggerService.log('Message to send: $message');

    // Validate phone number format (E.164)
    if (!_isValidE164(phoneNumber)) {
      return SmsResult.failure(
        error: 'Invalid phone number format. Use E.164 (e.g., +1234567890)',
        phoneNumber: phoneNumber,
      );
    }

    // Ensure we have credentials
    if (_credentials?.organizationId == null || _credentials?.userId == null) {
      LoggerService.log('Missing credentials, running bootstrap...');
      await bootstrap();
    }

    try {
      // Generate unique IDs
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Create a dedicated agent with this specific message as the starting_message
      // This ensures the actual summary gets sent, not a generic message
      final agentRequestBody = {
        'agent_type': 'sms',
        'agent_name': 'RoadRelay Summary $timestamp',
        'starting_message': message, // The actual summary!
        'prompt':
            'You have delivered a notification summary. If the user responds, be helpful and concise.',
        'organization_id': _credentials?.organizationId,
        'user_id': _credentials?.userId,
      };

      LoggerService.log(
          'Creating agent with body: ${json.encode(agentRequestBody)}');

      final agentResponse = await http
          .post(
            Uri.parse('$_baseUrl/v1/agents'),
            headers: _headers,
            body: json.encode(agentRequestBody),
          )
          .timeout(_timeout);

      LoggerService.log(
          'Agent response: ${agentResponse.statusCode} - ${agentResponse.body}');

      if (agentResponse.statusCode != 200 && agentResponse.statusCode != 201) {
        throw TeliApiException('Failed to create message agent',
            agentResponse.statusCode, agentResponse.body);
      }

      final agentData = json.decode(agentResponse.body) as Map<String, dynamic>;
      final messageAgentId = agentData['agent_id']?.toString();
      LoggerService.log(
          'Created message agent: $messageAgentId with starting_message: $message');

      // Now create the campaign with this agent
      final campaignId =
          '${timestamp}x${timestamp.toString().padLeft(18, '0')}';

      final requestBody = {
        'campaign_id': campaignId,
        'campaign_name': 'RoadRelay Summary $timestamp',
        'organization_id': _credentials?.organizationId,
        'user_id': _credentials?.userId,
        'sms_agent_id': messageAgentId,
        'teli_sms_number': _smsNumber,
        'contacts': [
          {
            'phone_number': phoneNumber,
            'first_name': 'Driver',
          }
        ],
      };

      LoggerService.log('Creating SMS campaign: $requestBody');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/v1/campaigns'),
            headers: _headers,
            body: json.encode(requestBody),
          )
          .timeout(_timeout);

      LoggerService.log(
          'Campaign response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final returnedCampaignId =
            data['campaign_id']?.toString() ?? campaignId;
        LoggerService.log('SMS campaign created: $returnedCampaignId');
        return SmsResult.success(
            messageId: returnedCampaignId, phoneNumber: phoneNumber);
      }

      throw TeliApiException(
          'SMS send failed', response.statusCode, response.body);
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
You are RoadRelay, a friendly driving assistant that reads notifications aloud to drivers.
Your job is to convert a list of notifications into a natural, conversational briefing.

Output strictly valid JSON with keys:
- sms_text (string, max 480 characters)
- narration_script (string, suitable for 30-60 second read)
- action_items (array of strings, 0-5 items)

Style Guidelines:
1. Sound like a helpful friend catching them up, NOT a robot reading a list
2. Use natural transitions: "Hey!", "Also...", "Oh, and...", "Heads up..."
3. Paraphrase notification titles into conversational language
4. Group related items naturally: "Your team has been busy on Slack..."
5. For calendar items: "You have [event] coming up" or "Don't forget about [event]"
6. For traffic: "Heads up, there's [issue] on your route"
7. For messages: "[Person/Team] wants to let you know..." or "[App] says..."
8. If sensitive=true, say "There's a private alert from [app]" without details

Rules:
1. Keep sms_text under 480 characters
2. Keep narration_script conversational and under 60 seconds when read aloud
3. Prioritize urgent/high priority items first but weave them in naturally
4. End with something like "That's the quick update!" or count of remaining items
5. Never sound robotic or list-like - you're a helpful co-pilot!
''';
}

class TeliApiException implements Exception {
  final String message;
  final int statusCode;
  final String responseBody;

  TeliApiException(this.message, this.statusCode, this.responseBody);

  @override
  String toString() =>
      'TeliApiException: $message (HTTP $statusCode): $responseBody';
}
