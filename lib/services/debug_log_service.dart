import 'package:flutter/foundation.dart';

enum DebugLogLevel { info, warning, error }

class DebugLogEntry {
  final DateTime timestamp;
  final DebugLogLevel level;
  final String tag;
  final String message;

  const DebugLogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
  });

  String get line {
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    final ss = timestamp.second.toString().padLeft(2, '0');
    return '[$hh:$mm:$ss] [${level.name.toUpperCase()}] [$tag] $message';
  }
}

class DebugLogService extends ChangeNotifier {
  final List<DebugLogEntry> _entries = [];

  List<DebugLogEntry> get entries => List.unmodifiable(_entries.reversed);

  void info(String tag, String message) => _add(DebugLogLevel.info, tag, message);

  void warning(String tag, String message) =>
      _add(DebugLogLevel.warning, tag, message);

  void error(String tag, String message) => _add(DebugLogLevel.error, tag, message);

  void clear() {
    _entries.clear();
    notifyListeners();
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
    debugPrint(_entries.last.line);
    notifyListeners();
  }
}
