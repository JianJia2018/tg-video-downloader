import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tg_video_downloader/services/download_manager.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dm = context.watch<DownloadManager>();
    final theme = Theme.of(context);
    final active = dm.activeTasks;
    final completed = dm.completedTasks;

    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: (active.isEmpty && completed.isEmpty)
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_done,
                      size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No downloads yet',
                      style: theme.textTheme.titleMedium),
                ],
              ),
            )
          : ListView(
              children: [
                if (active.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('Active',
                        style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary)),
                  ),
                  ...active.map((task) => _DownloadTile(
                        task: task,
                        onCancel: () => dm.cancelDownload(task.fileId),
                      )),
                ],
                if (completed.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('Completed',
                        style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary)),
                  ),
                  ...completed.map((task) => _DownloadTile(
                        task: task,
                        onRemove: () => dm.removeTask(task.fileId),
                      )),
                ],
              ],
            ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback? onCancel;
  final VoidCallback? onRemove;

  const _DownloadTile({
    required this.task,
    this.onCancel,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(
          task.isCompleted ? Icons.check_circle : Icons.downloading,
          color: task.isCompleted
              ? theme.colorScheme.primary
              : theme.colorScheme.secondary,
        ),
        title: Text(task.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!task.isCompleted) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(value: task.progress),
            ],
            const SizedBox(height: 2),
            Text(
              task.isCompleted
                  ? task.localPath ?? 'Downloaded'
                  : task.progressText,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: task.isCompleted
            ? IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onRemove,
              )
            : IconButton(
                icon: const Icon(Icons.cancel_outlined),
                onPressed: onCancel,
              ),
      ),
    );
  }
}
