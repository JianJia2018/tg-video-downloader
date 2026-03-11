import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:handy_tdlib/client.dart';
import 'package:handy_tdlib/handy_tdlib.dart' show convertJsonToObject;
import 'package:handy_tdlib/api.dart' as td;

/// Message types for Isolate communication
enum _IsolateMessageType {
  start,
  stop,
  sendResult,
  error,
}

class _IsolateMessage {
  final _IsolateMessageType type;
  final dynamic data;

  _IsolateMessage(this.type, [this.data]);
}

/// Entry point for the TDLib updates Isolate.
/// This Isolate runs the tdReceive() loop and parses JSON responses
/// off the main thread, reducing UI jank.
void _tdlibUpdatesIsolateEntry(SendPort mainSendPort) {
  Timer? pollTimer;
  final mainReceivePort = ReceivePort();

  // Send back our receive port so main isolate can send us commands
  mainSendPort.send(mainReceivePort.sendPort);

  // Listen for commands from main isolate
  mainReceivePort.listen((message) {
    if (message is _IsolateMessage) {
      switch (message.type) {
        case _IsolateMessageType.start:
          final clientId = message.data as int;
          _startPolling(clientId, mainSendPort);
          break;
        case _IsolateMessageType.stop:
          pollTimer?.cancel();
          break;
        default:
          break;
      }
    }
  });
}

/// Start polling TDLib for updates in this isolate
void _startPolling(int clientId, SendPort mainSendPort) {
  const pollInterval = Duration(milliseconds: 100);
  const maxUpdatesPerDrain = 50; // Process more per tick since we're off-main-thread

  var isDraining = false;

  Timer.periodic(pollInterval, (timer) {
    if (isDraining) return;

    isDraining = true;
    try {
      var processed = 0;
      while (processed < maxUpdatesPerDrain) {
        final rawResponse = TdPlugin.instance.tdReceive(0);

        if (rawResponse == null) {
          break;
        }

        // Parse JSON in this isolate (off main thread)
        final parsed = _parseTdLibResponse(rawResponse);
        if (parsed != null) {
          // Send parsed object back to main isolate
          mainSendPort.send(_IsolateMessage(_IsolateMessageType.sendResult, parsed));
        }

        processed++;
      }
    } catch (e) {
      mainSendPort.send(_IsolateMessage(_IsolateMessageType.error, e.toString()));
    } finally {
      isDraining = false;
    }
  });
}

/// Parse TDLib JSON response
dynamic _parseTdLibResponse(String rawJson) {
  try {
    final decoded = jsonDecode(rawJson);
    if (decoded is Map<String, dynamic>) {
      final obj = convertJsonToObject(decoded);
      return obj;
    }
  } catch (e) {
    // Return raw error on parse failure
    return {'@type': 'error', 'message': 'Parse error: $e'};
  }
  return null;
}

/// Manages TDLib updates in a background Isolate
///
/// This service creates and manages a dedicated Isolate that:
/// - Polls TDLib for updates (tdReceive)
/// - Parses JSON responses off the main thread
/// - Sends parsed objects back to main thread via SendPort
///
/// Benefits:
/// - JSON parsing (CPU intensive) happens off main thread
/// - Reduces UI jank during high update frequency
/// - Main isolate only handles lightweight message passing
class TdlibIsolateService {
  Isolate? _updatesIsolate;
  SendPort? _updatesSendPort;
  ReceivePort? _updatesReceivePort;
  final StreamController<td.TdObject> _updateController =
      StreamController<td.TdObject>.broadcast();

  /// Stream of parsed TDLib updates
  Stream<td.TdObject> get updates => _updateController.stream;

  /// Start the updates isolate
  Future<void> start(int clientId) async {
    if (_updatesIsolate != null) {
      await stop();
    }

    _updatesReceivePort = ReceivePort();

    // Create the updates isolate
    _updatesIsolate = await Isolate.spawn(
      _tdlibUpdatesIsolateEntry,
      _updatesReceivePort!.sendPort,
    );

    // Wait for the isolate to send us its SendPort
    final completer = Completer<SendPort>();
    late StreamSubscription subscription;

    subscription = _updatesReceivePort!.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
        subscription.cancel();
      } else if (message is _IsolateMessage) {
        _handleIsolateMessage(message);
      }
    });

    _updatesSendPort = await completer.future;

    // Listen for updates from the isolate
    _updatesReceivePort!.listen((message) {
      if (message is _IsolateMessage) {
        _handleIsolateMessage(message);
      }
    });

    // Start polling in the isolate
    _updatesSendPort!.send(_IsolateMessage(_IsolateMessageType.start, clientId));
  }

  /// Handle messages from the updates isolate
  void _handleIsolateMessage(_IsolateMessage message) {
    switch (message.type) {
      case _IsolateMessageType.sendResult:
        if (message.data is td.TdObject) {
          _updateController.add(message.data as td.TdObject);
        }
        break;
      case _IsolateMessageType.error:
        // Log error but don't crash
        print('TdlibIsolateService error: ${message.data}');
        break;
      default:
        break;
    }
  }

  /// Stop the updates isolate
  Future<void> stop() async {
    _updatesSendPort?.send(_IsolateMessage(_IsolateMessageType.stop));
    _updatesReceivePort?.close();
    _updatesIsolate?.kill(priority: Isolate.immediate);
    _updatesIsolate = null;
    _updatesSendPort = null;
    _updatesReceivePort = null;
  }

  /// Dispose resources
  void dispose() {
    stop();
    _updateController.close();
  }
}
