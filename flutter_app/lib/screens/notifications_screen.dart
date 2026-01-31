import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/notification.dart';
import '../services/app_state.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final notifications = appState.notifications;
        final grouped = appState.notificationService.getGroupedByCategory();

        return CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: const Text('Notifications'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: appState.reloadNotifications,
                  tooltip: 'Reload',
                ),
              ],
            ),
            if (notifications.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text('No notifications loaded'),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final categories = grouped.keys.toList()..sort();
                      final widgets = <Widget>[];

                      for (final category in categories) {
                        widgets.add(_buildCategoryHeader(context, category));
                        for (final notification in grouped[category]!) {
                          widgets.add(_buildNotificationCard(context, notification));
                        }
                        widgets.add(const SizedBox(height: 16));
                      }

                      if (index < widgets.length) {
                        return widgets[index];
                      }
                      return null;
                    },
                    childCount: _calculateChildCount(grouped),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  int _calculateChildCount(Map<String, List<AppNotification>> grouped) {
    int count = 0;
    for (final category in grouped.keys) {
      count += 1; // Header
      count += grouped[category]!.length; // Notifications
      count += 1; // Spacing
    }
    return count;
  }

  Widget _buildCategoryHeader(BuildContext context, String category) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        category.toUpperCase(),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, AppNotification notification) {
    final priorityColor = _getPriorityColor(notification.priority);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showNotificationDetails(context, notification),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildAppIcon(notification.app),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            notification.app,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                        if (notification.sensitive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SENSITIVE',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.sensitive ? '[Content hidden]' : notification.body,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          notification.sender,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const Spacer(),
                        Text(
                          _formatTime(notification.timestamp),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppIcon(String app) {
    IconData icon;
    switch (app.toLowerCase()) {
      case 'slack':
        icon = Icons.tag;
        break;
      case 'gmail':
      case 'outlook':
        icon = Icons.email;
        break;
      case 'calendar':
        icon = Icons.calendar_today;
        break;
      case 'messages':
      case 'whatsapp':
        icon = Icons.message;
        break;
      case 'weather':
        icon = Icons.cloud;
        break;
      case 'chase bank':
      case 'bank of america':
      case 'venmo':
        icon = Icons.account_balance;
        break;
      case 'google authenticator':
      case 'duo mobile':
        icon = Icons.security;
        break;
      case 'twitter':
      case 'instagram':
        icon = Icons.public;
        break;
      case 'uber':
        icon = Icons.local_taxi;
        break;
      case 'fitbit':
        icon = Icons.fitness_center;
        break;
      case 'news':
      case 'ap news':
        icon = Icons.newspaper;
        break;
      default:
        icon = Icons.notifications;
    }
    return Icon(icon, size: 18);
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return DateFormat('MMM d').format(dt);
    }
  }

  void _showNotificationDetails(BuildContext context, AppNotification notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.25,
        maxChildSize: 0.75,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _buildAppIcon(notification.app),
                    const SizedBox(width: 8),
                    Text(
                      notification.app,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(notification.priority).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        notification.priority.toUpperCase(),
                        style: TextStyle(
                          color: _getPriorityColor(notification.priority),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  notification.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                if (notification.sensitive)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This notification contains sensitive content and will be redacted in summaries.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    notification.body,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                const SizedBox(height: 24),
                _buildDetailRow(context, 'From', notification.sender),
                _buildDetailRow(context, 'Category', notification.category),
                _buildDetailRow(
                  context,
                  'Time',
                  DateFormat('MMM d, yyyy HH:mm').format(notification.timestamp),
                ),
                _buildDetailRow(context, 'ID', notification.id),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
