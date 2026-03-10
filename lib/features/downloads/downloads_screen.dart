import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tg_video_downloader/services/download_manager.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: Selector<DownloadManager, ({List<int> activeIds, List<int> completedIds})>(
        selector: (_, manager) => (
          activeIds: manager.activeTasks.map((task) => task.fileId).toList(),
          completedIds:
              manager.completedTasks.map((task) => task.fileId).toList(),
        ),
        builder: (context, ids, _) {
          if (ids.activeIds.isEmpty && ids.completedIds.isEmpty) {
            return Center(
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
            );
          }

          return ListView(
            children: [
              if (ids.activeIds.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Active',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: theme.colorScheme.primary)),
                ),
                ...ids.activeIds.map(
                  (fileId) => _DownloadTile(
                    fileId: fileId,
                    onCancel: () =>
                        context.read<DownloadManager>().cancelDownload(fileId),
                  ),
                ),
              ],
              if (ids.completedIds.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Completed',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: theme.colorScheme.primary)),
                ),
                ...ids.completedIds.map(
                  (fileId) => _DownloadTile(
                    fileId: fileId,
                    onRemove: () =>
                        context.read<DownloadManager>().removeTask(fileId),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final int fileId;
  final VoidCallback? onCancel;
  final VoidCallback? onRemove;

  const _DownloadTile({
    required this.fileId,
    this.onCancel,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<DownloadManager, DownloadTaskSnapshot?>(
      selector: (_, manager) => manager.snapshotForFile(fileId),
      builder: (context, task, _) {
        if (task == null) {
          return const SizedBox.shrink();
        }

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
            title: Text(task.fileName,
                maxLines: 1, overflow: TextOverflow.ellipsis),
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
      },
    );
  }
}
