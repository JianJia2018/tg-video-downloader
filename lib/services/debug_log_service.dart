import 'package:flutter/foundation.dart';
import 'dart:async';

enum DebugLogLevel { info, warning, error }

class DebugLogEntry {
  final DateTime timestamp;
  final DebugLogLevel level;
  final String tag;
  final String message;
  final String line;

  DebugLogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
  }) : line = _buildLine(timestamp, level, tag, message);

  static String _buildLine(
    DateTime timestamp,
    DebugLogLevel level,
    String tag,
    String message,
  ) {
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    final ss = timestamp.second.toString().padLeft(2, '0');
    return '[$hh:$mm:$ss] [${level.name.toUpperCase()}] [$tag] $message';
  }
}

class DebugLogService extends ChangeNotifier {
  final List<DebugLogEntry> _entries = [];
  bool _notifyScheduled = false;
  int _revision = 0;

  int get entryCount => _entries.length;
  int get revision => _revision;

  DebugLogEntry entryAtReversedIndex(int index) {
    return _entries[_entries.length - 1 - index];
  }

  String exportText() {
    if (_entries.isEmpty) {
      return '';
    }
    return _entries.map((e) => e.line).join('\n');
  }

  void info(String tag, String message) => _add(DebugLogLevel.info, tag, message);

  void warning(String tag, String message) =>
      _add(DebugLogLevel.warning, tag, message);

  void error(String tag, String message) => _add(DebugLogLevel.error, tag, message);

  void clear() {
    _entries.clear();
    _revision++;
    _scheduleNotify();
  }

  void _add(DebugLogLevel level, String tag, String message) {
    _entries.add(
      DebugLogEntry(
        timestamp: DateTime.now(),
        level: level,
        tag: tag,
        message: message,
      ),
    );
    if (_entries.length > 500) {
      _entries.removeRange(0, _entries.length - 500);
    }
    _revision++;
    if (kDebugMode) {
      debugPrint(_entries.last.line);
    }
    _scheduleNotify();
  }

  void _scheduleNotify() {
    if (_notifyScheduled) {
      return;
    }
    _notifyScheduled = true;
    Timer(const Duration(milliseconds: 80), () {
      _notifyScheduled = false;
      notifyListeners();
    });
  }
}
