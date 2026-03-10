import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tg_video_downloader/services/debug_log_service.dart';

class DebugLogScreen extends StatelessWidget {
  const DebugLogScreen({super.key});

  static const _rowTextStyle = TextStyle(fontFamily: 'monospace');

  @override
  Widget build(BuildContext context) {
    final logs = context.read<DebugLogService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () async {
              final text = logs.exportText();
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logs copied')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              final text = logs.exportText();
              if (text.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No logs to share')),
                  );
                }
                return;
              }

              await Share.share(
                text,
                subject: 'TG Video Downloader Debug Logs',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: logs.clear,
          ),
        ],
      ),
      body: Selector<DebugLogService, ({int count, int revision})>(
        selector: (_, service) => (
          count: service.entryCount,
          revision: service.revision,
        ),
        builder: (context, snapshot, _) {
          if (snapshot.count == 0) {
            return Center(
              child: Text(
                'No logs yet',
                style: theme.textTheme.titleMedium,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.count,
            itemBuilder: (context, index) {
              final entry = logs.entryAtReversedIndex(index);
              final color = switch (entry.level) {
                DebugLogLevel.info => theme.colorScheme.primary,
                DebugLogLevel.warning => Colors.orange,
                DebugLogLevel.error => theme.colorScheme.error,
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RepaintBoundary(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      entry.line,
                      style: (theme.textTheme.bodySmall ?? _rowTextStyle).copyWith(
                        fontFamily: _rowTextStyle.fontFamily,
                        color: color,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
