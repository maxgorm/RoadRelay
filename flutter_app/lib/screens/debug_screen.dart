import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/logger_service.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild periodically to show new logs
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return Scaffold(
          appBar: AppBar(
            title: const Text('Debug Logs'),
            actions: [
              IconButton(
                icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center),
                onPressed: () => setState(() => _autoScroll = !_autoScroll),
                tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: _copyLogs,
                tooltip: 'Copy logs',
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _clearLogs,
                tooltip: 'Clear logs',
              ),
            ],
          ),
          body: Column(
            children: [
              _buildStatsBar(),
              Expanded(
                child: _buildLogsList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsBar() {
    final logs = LoggerService.logs;
    final errorCount = logs.where((l) => l.isError).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(
            Icons.article,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '${logs.length} entries',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(width: 16),
          if (errorCount > 0) ...[
            Icon(
              Icons.error,
              size: 16,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 4),
            Text(
              '$errorCount errors',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogsList() {
    final logs = LoggerService.logs;

    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No logs yet',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Logs will appear as you use the app',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return _buildLogEntry(log);
      },
    );
  }

  Widget _buildLogEntry(LogEntry log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: log.isError
            ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.3)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: log.isError
              ? Theme.of(context).colorScheme.error.withOpacity(0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            log.formattedTime,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontFamily: 'monospace',
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(width: 8),
          if (log.isError)
            Icon(
              Icons.error,
              size: 14,
              color: Theme.of(context).colorScheme.error,
            )
          else
            Icon(
              Icons.circle,
              size: 8,
              color: Theme.of(context).colorScheme.primary,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              log.message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: log.isError
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyLogs() {
    final logsText = LoggerService.exportLogs();
    Clipboard.setData(ClipboardData(text: logsText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs?'),
        content: const Text('This will delete all debug logs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              LoggerService.clear();
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
