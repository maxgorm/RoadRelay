import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'notifications_screen.dart';
import 'debug_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _phoneController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showPhoneInput = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      _phoneController.text = appState.phoneNumber;
      // Show input if phone number is not set
      if (appState.phoneNumber.isEmpty) {
        setState(() {
          _showPhoneInput = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: _buildHomeContent(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.directions_car,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'RoadRelay',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Developer Tools',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Sample Notifications'),
            subtitle: const Text('View test notification data'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Debug Logs'),
            subtitle: const Text('View app logs and diagnostics'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DebugScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('RoadRelay v1.0'),
            onTap: () {
              Navigator.pop(context);
              showAboutDialog(
                context: context,
                applicationName: 'RoadRelay',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.directions_car, size: 48),
                children: [
                  const Text('Your friendly driving notification assistant.'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return CustomScrollView(
          slivers: [
            SliverAppBar.large(
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                tooltip: 'Menu',
              ),
              title: const Text('RoadRelay'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed:
                      appState.isLoading ? null : appState.reloadNotifications,
                  tooltip: 'Reload notifications',
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSensitiveToggle(appState),
                  const SizedBox(height: 24),
                  _buildSendButton(appState),
                  const SizedBox(height: 24),
                  _buildStatusCard(appState),
                  const SizedBox(height: 16),
                  _buildLastSummaryCard(appState),
                  const SizedBox(height: 16),
                  if (_showPhoneInput || appState.phoneNumber.isEmpty)
                    _buildPhoneInput(appState)
                  else
                    _buildPhoneChip(appState),
                  const SizedBox(height: 16),
                  _buildStatsCard(appState),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPhoneInput(AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phone Number',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '+1234567890',
                helperText: 'E.164 format (e.g., +1234567890)',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                appState.setPhoneNumber(value);
              },
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  setState(() {
                    _showPhoneInput = false;
                  });
                }
              },
            ),
            if (appState.phoneNumber.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showPhoneInput = false;
                    });
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Done'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneChip(AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.phone, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                appState.phoneNumber,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showPhoneInput = true;
                });
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensitiveToggle(AppState appState) {
    return Card(
      child: SwitchListTile(
        title: const Text('Include Sensitive Content'),
        subtitle: const Text('Include bank alerts, 2FA codes, etc. in SMS'),
        value: appState.includeSensitive,
        onChanged: appState.setIncludeSensitive,
        secondary: Icon(
          appState.includeSensitive ? Icons.lock_open : Icons.lock,
          color: appState.includeSensitive
              ? Theme.of(context).colorScheme.error
              : null,
        ),
      ),
    );
  }

  Widget _buildSendButton(AppState appState) {
    return Column(
      children: [
        // Voice Query Button
        OutlinedButton.icon(
          onPressed:
              appState.isLoading ? null : () => _handleVoiceQuery(appState),
          icon: const Icon(Icons.mic),
          label: const Text('Ask About Notifications'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
          ),
        ),
        const SizedBox(height: 12),
        // Send Summary Button
        FilledButton.icon(
          onPressed: appState.isLoading || appState.phoneNumber.isEmpty
              ? null
              : appState.runSummaryWorkflow,
          icon: appState.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: Text(appState.isLoading ? 'Sending...' : 'Test Send Summary'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
          ),
        ),
      ],
    );
  }

  Future<void> _handleVoiceQuery(AppState appState) async {
    bool dialogOpen = false;

    void closeDialog() {
      if (dialogOpen && mounted) {
        dialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    try {
      // Request permission if needed
      final hasPermission =
          await appState.voiceQueryService.requestPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Microphone permission is required for voice queries'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Set up callbacks to dismiss dialog when speech completes
      appState.voiceQueryService.onSpeechResult = (text) {
        closeDialog();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Processing: "$text"'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      };

      appState.voiceQueryService.onSpeechError = (error) {
        closeDialog();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Speech error: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      };

      // Show listening dialog with Done button
      if (mounted) {
        dialogOpen = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic, size: 64, color: Colors.blue),
                SizedBox(height: 16),
                Text('Listening...', style: TextStyle(fontSize: 18)),
                SizedBox(height: 8),
                Text('Ask about your notifications'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await appState.voiceQueryService.stopListening();
                  dialogOpen = false;
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }

      // Start listening
      await appState.voiceQueryService.startListening();
    } catch (e) {
      closeDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice query error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatusCard(AppState appState) {
    final hasError = appState.error != null;
    final hasSuccess = appState.lastSmsResult?.success == true;

    return Card(
      color: hasError
          ? Theme.of(context).colorScheme.errorContainer
          : hasSuccess
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasError
                      ? Icons.error
                      : hasSuccess
                          ? Icons.check_circle
                          : Icons.info,
                  color: hasError
                      ? Theme.of(context).colorScheme.error
                      : hasSuccess
                          ? Theme.of(context).colorScheme.primary
                          : null,
                ),
                const SizedBox(width: 8),
                Text(
                  'Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (hasError)
              Text(
                appState.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (appState.lastSmsResult != null) ...[
              Text(
                appState.lastSmsResult!.success
                    ? '✓ SMS sent successfully'
                    : '✗ SMS failed: ${appState.lastSmsResult!.error}',
              ),
              const SizedBox(height: 4),
              Text(
                'To: ${appState.lastSmsResult!.phoneNumber}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'At: ${_formatDateTime(appState.lastSmsResult!.timestamp)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else
              const Text('No summary sent yet'),
          ],
        ),
      ),
    );
  }

  Widget _buildLastSummaryCard(AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description),
                const SizedBox(width: 8),
                Text(
                  'Last Summary',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (appState.lastSummary != null) ...[
              Text(
                'SMS Text (${appState.lastSummary!.smsText.length}/480 chars):',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  appState.lastSummary!.smsText,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (appState.lastSummary!.actionItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Action Items:',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                ...appState.lastSummary!.actionItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(item)),
                      ],
                    ),
                  ),
                ),
              ],
            ] else
              Text(
                'No summary generated yet. Tap "Test Send Summary" to create one.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(AppState appState) {
    final stats = appState.notificationService.getStats();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics),
                const SizedBox(width: 8),
                Text(
                  'Notification Stats',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatChip('Total', stats['total'] ?? 0, Colors.blue),
                _buildStatChip('High', stats['high'] ?? 0, Colors.red),
                _buildStatChip('Medium', stats['medium'] ?? 0, Colors.orange),
                _buildStatChip('Low', stats['low'] ?? 0, Colors.green),
                _buildStatChip(
                    'Sensitive', stats['sensitive'] ?? 0, Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      label: Text(label),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
