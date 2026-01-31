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
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      _phoneController.text = appState.phoneNumber;
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
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeContent(),
          const NotificationsScreen(),
          const DebugScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          NavigationDestination(
            icon: Icon(Icons.bug_report_outlined),
            selectedIcon: Icon(Icons.bug_report),
            label: 'Debug',
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
              title: const Text('DriveBrief'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: appState.isLoading ? null : appState.reloadNotifications,
                  tooltip: 'Reload notifications',
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildPhoneInput(appState),
                  const SizedBox(height: 16),
                  _buildSensitiveToggle(appState),
                  const SizedBox(height: 24),
                  _buildSendButton(appState),
                  const SizedBox(height: 24),
                  _buildStatusCard(appState),
                  const SizedBox(height: 16),
                  _buildLastSummaryCard(appState),
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
              onChanged: (value) => appState.setPhoneNumber(value),
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
    return FilledButton.icon(
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
    );
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
                _buildStatChip('Sensitive', stats['sensitive'] ?? 0, Colors.purple),
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
