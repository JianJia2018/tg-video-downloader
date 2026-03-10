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
    this.localPath,
  });

  double get progress =>
      totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;

  String get progressText {
    final downloaded = (downloadedBytes / 1024 / 1024).toStringAsFixed(1);
    final total = (totalBytes / 1024 / 1024).toStringAsFixed(1);
    return '$downloaded / $total MB';
  }
}

class DownloadTaskSnapshot {
  final int fileId;
  final String fileName;
  final double progress;
  final String progressText;
  final bool isCompleted;
  final bool isCancelled;
  final String? localPath;

  const DownloadTaskSnapshot({
    required this.fileId,
    required this.fileName,
    required this.progress,
    required this.progressText,
    required this.isCompleted,
    required this.isCancelled,
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
        localPath,
      );
}

/// Manages download queue and progress tracking
class DownloadManager extends ChangeNotifier {
  final Map<int, DownloadTask> _tasks = {};
  TdlibService? _tdlib;
  StreamSubscription? _updateSubscription;
  Timer? _progressNotifyTimer;

  List<DownloadTask> get tasks => _tasks.values.toList();
  List<DownloadTask> get activeTasks =>
      _tasks.values.where((t) => !t.isCompleted && !t.isCancelled).toList();
  List<DownloadTask> get completedTasks =>
      _tasks.values.where((t) => t.isCompleted).toList();
  DownloadTask? taskForFile(int fileId) => _tasks[fileId];
  DownloadTaskSnapshot? snapshotForFile(int fileId) {
    final task = _tasks[fileId];
    if (task == null) {
      return null;
    }

    return DownloadTaskSnapshot.fromTask(task);
  }

  void attachTdlib(TdlibService tdlib) {
    _tdlib = tdlib;
    _updateSubscription?.cancel();
    _updateSubscription = tdlib.updates.listen(_handleUpdate);
  }

  void _handleUpdate(td.TdObject update) {
    if (update is td.UpdateFile) {
      final file = update.file;
      final task = _tasks[file.id];
      if (task == null) return;

      final previousBytes = task.downloadedBytes;
      final previousCompleted = task.isCompleted;
      final previousPath = task.localPath;

      task.downloadedBytes = file.local.downloadedSize;
      task.isCompleted = file.local.isDownloadingCompleted;
      if (task.isCompleted) {
        task.localPath = file.local.path;
      }

      final changed = previousBytes != task.downloadedBytes ||
          previousCompleted != task.isCompleted ||
          previousPath != task.localPath;
      if (changed) {
        _scheduleProgressNotify();
      }
    }
  }

  void _scheduleProgressNotify() {
    if (_progressNotifyTimer?.isActive ?? false) {
      return;
    }

    _progressNotifyTimer = Timer(
      const Duration(milliseconds: 80),
      notifyListeners,
    );
  }

  Future<void> startDownload({
    required int fileId,
    required int chatId,
    required int messageId,
    required String fileName,
    required int totalBytes,
  }) async {
    if (_tdlib == null) return;
    if (_tasks.containsKey(fileId)) return; // Already downloading

    _tasks[fileId] = DownloadTask(
      fileId: fileId,
      chatId: chatId,
      messageId: messageId,
      fileName: fileName,
      totalBytes: totalBytes,
    );
    notifyListeners();

    await _tdlib!.downloadFile(fileId);
  }

  Future<void> cancelDownload(int fileId) async {
    final task = _tasks[fileId];
    if (task == null) return;

    task.isCancelled = true;
    await _tdlib?.cancelDownload(fileId);
    notifyListeners();
  }

  void removeTask(int fileId) {
    _tasks.remove(fileId);
    notifyListeners();
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    _progressNotifyTimer?.cancel();
    super.dispose();
  }
}
