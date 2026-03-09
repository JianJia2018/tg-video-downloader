import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tg_video_downloader/services/debug_log_service.dart';

class DebugLogScreen extends StatelessWidget {
  const DebugLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<DebugLogService>();
    final theme = Theme.of(context);
    final entries = logs.entries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () async {
              final text = entries.map((e) => e.line).join('\n');
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
              final text = entries.map((e) => e.line).join('\n');
              if (text.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No logs to share')),
                  );
                }
                return;
              }

              await SharePlus.instance.share(
                ShareParams(
                  text: text,
                  subject: 'TG Video Downloader Debug Logs',
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: logs.clear,
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Text(
                'No logs yet',
                style: theme.textTheme.titleMedium,
              ),
            )
          : ListView.separated(
              reverse: false,
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final color = switch (entry.level) {
                  DebugLogLevel.info => theme.colorScheme.primary,
                  DebugLogLevel.warning => Colors.orange,
                  DebugLogLevel.error => theme.colorScheme.error,
                };
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.35)),
                  ),
                  child: SelectableText(
                    entry.line,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: color,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
