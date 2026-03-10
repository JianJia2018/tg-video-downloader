import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:tg_video_downloader/services/tdlib_service.dart';

/// Represents a single download task
class DownloadTask {
  final int fileId;
  final int chatId;
  final int messageId;
  final String fileName;
  final int totalBytes;
  int downloadedBytes;
  bool isCompleted;
  bool isCancelled;
  bool isFailed;
  String? localPath;

  DownloadTask({
    required this.fileId,
    required this.chatId,
    required this.messageId,
    required this.fileName,
    required this.totalBytes,
    this.downloadedBytes = 0,
    this.isCompleted = false,
    this.isCancelled = false,
    this.isFailed = false,
    this.localPath,
  });

  double get progress {
    if (totalBytes <= 0) return 0;
    return downloadedBytes / totalBytes;
  }

  String get progressText {
    if (isCompleted) return 'Completed';
    if (isCancelled) return 'Cancelled';
    if (isFailed) return 'Failed';
    if (totalBytes <= 0) return 'Preparing...';
    final downloaded = _formatBytes(downloadedBytes);
    final total = _formatBytes(totalBytes);
    final percent = (progress * 100).toStringAsFixed(0);
    return '$downloaded / $total ($percent%)';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Immutable snapshot of a download task for UI consumption
class DownloadTaskSnapshot {
  final int fileId;
  final String fileName;
  final double progress;
  final String progressText;
  final bool isCompleted;
  final bool isCancelled;
  final bool isFailed;
  final String? localPath;

  const DownloadTaskSnapshot({
    required this.fileId,
    required this.fileName,
    required this.progress,
    required this.progressText,
    required this.isCompleted,
    required this.isCancelled,
    required this.isFailed,
    required this.localPath,
  });

  factory DownloadTaskSnapshot.fromTask(DownloadTask task) {
    return DownloadTaskSnapshot(
      fileId: task.fileId,
      fileName: task.fileName,
      progress: task.progress,
      progressText: task.progressText,
      isCompleted: task.isCompleted,
      isCancelled: task.isCancelled,
      isFailed: task.isFailed,
      localPath: task.localPath,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is DownloadTaskSnapshot &&
        other.fileId == fileId &&
        other.fileName == fileName &&
        other.progress == progress &&
        other.progressText == progressText &&
        other.isCompleted == isCompleted &&
        other.isCancelled == isCancelled &&
        other.isFailed == isFailed &&
        other.localPath == localPath;
  }

  @override
  int get hashCode => Object.hash(
        fileId,
        fileName,
        progress,
        progressText,
        isCompleted,
        isCancelled,
        isFailed,
        localPath,
      );
}

/// Manages download queue and tracks download progress
class DownloadManager extends ChangeNotifier {
  TdlibService? _tdlib;
  final Map<int, DownloadTask> _tasks = {};

  void setTdlib(TdlibService tdlib) {
    _tdlib = tdlib;
  }

  /// Start downloading a file
  Future<void> startDownload({
    required int fileId,
    required int chatId,
    required int messageId,
    required String fileName,
    required int totalBytes,
  }) async {
    if (_tasks.containsKey(fileId)) {
      // Already downloading
      return;
    }

    _tasks[fileId] = DownloadTask(
      fileId: fileId,
      chatId: chatId,
      messageId: messageId,
      fileName: fileName,
      totalBytes: totalBytes,
      isFailed: false,
    );
    notifyListeners();

    await _tdlib?.downloadFile(fileId);
  }

  /// Cancel a download
  void cancelDownload(int fileId) {
    final task = _tasks[fileId];
    if (task != null && !task!.isCompleted) {
      task!.isCancelled = true;
      notifyListeners();
      _tasks.remove(fileId);
      notifyListeners();
    }
  }

  /// Remove a completed task from list
  void removeTask(int fileId) {
    if (_tasks.containsKey(fileId)) {
      _tasks.remove(fileId);
      notifyListeners();
    }
  }

  /// Handle file download progress updates from TDLib
  void handleFileUpdate(td.UpdateFile update) {
    final file = update.file;
    final task = _tasks[file.id];

    if (task != null) {
      task!.downloadedBytes = file.local.downloadedSize;
      task!.localPath = file.local.path;

      if (file.local.isDownloadingCompleted) {
        task!.isCompleted = true;
        task!.isFailed = false;
        notifyListeners();
        // Keep completed tasks briefly for UI feedback
        Future.delayed(const Duration(seconds: 5), () {
          _tasks.remove(file.id);
          notifyListeners();
        });
      } else {
        notifyListeners();
      }
    }
  }

  /// Handle download errors
  void handleDownloadError(int fileId, String error) {
    final task = _tasks[fileId];
    if (task != null) {
      task!.isFailed = true;
      notifyListeners();
    }
  }

  /// Get snapshot for a specific file
  DownloadTaskSnapshot? snapshotForFile(int fileId) {
    final task = _tasks[fileId];
    if (task == null) return null;
    return DownloadTaskSnapshot.fromTask(task);
  }

  /// Get all active tasks
  List<DownloadTaskSnapshot> get activeTasks {
    return _tasks.values
        .where((t) => !t.isCompleted && !t.isCancelled && !t.isFailed)
        .map((t) => DownloadTaskSnapshot.fromTask(t))
        .toList();
  }

  /// Get all completed tasks
  List<DownloadTaskSnapshot> get completedTasks {
    return _tasks.values
        .where((t) => t.isCompleted)
        .map((t) => DownloadTaskSnapshot.fromTask(t))
        .toList();
  }

  /// Clear all completed tasks
  void clearCompleted() {
    _tasks.removeWhere((_, task) => task.isCompleted);
    notifyListeners();
  }
}
