import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:handy_tdlib/client.dart';
import 'package:path_provider/path_provider.dart';

/// Core TDLib service — manages client lifecycle, auth, and API calls.
///
/// Uses two Dart Isolates:
///   - Invokes isolate: sends requests to TDLib
///   - Updates isolate: receives responses and updates from TDLib
class TdlibService extends ChangeNotifier {
  int? _clientId;
  bool _isInitialized = false;
  bool _isAuthorized = false;

  // Auth state
  String _authState = 'initial';
  String? _authError;

  // Stream controller for TDLib updates
  final _updateController = StreamController<td.TdObject>.broadcast();
  Stream<td.TdObject> get updates => _updateController.stream;

  bool get isInitialized => _isInitialized;
  bool get isAuthorized => _isAuthorized;
  String get authState => _authState;
  String? get authError => _authError;
  int? get clientId => _clientId;

  // Pending invoke completers keyed by 'extra' field
  final Map<String, Completer<td.TdObject>> _pendingInvokes = {};

  TdlibService() {
    _init();
  }

  Future<void> _init() async {
    _clientId = TdPlugin.instance.tdCreateClientId();

    // Start updates listener in background isolate
    _startUpdatesListener();

    // Send initial parameters
    final appDir = await getApplicationDocumentsDirectory();
    await invoke(td.SetTdlibParameters(
      apiId: const int.fromEnvironment('TELEGRAM_API_ID'),
      apiHash: const String.fromEnvironment('TELEGRAM_API_HASH'),
      databaseDirectory: '${appDir.path}/tdlib',
      filesDirectory: '${appDir.path}/tdlib_files',
      useMessageDatabase: true,
      useFileDatabase: true,
      useChatInfoDatabase: true,
      useSecretChats: false,
      systemLanguageCode: 'en',
      deviceModel: 'Android',
      applicationVersion: '0.1.0',
      systemVersion: 'Android',
      databaseEncryptionKey: '',
      enableStorageOptimizer: true,
    ));

    _isInitialized = true;
    notifyListeners();
  }

  void _startUpdatesListener() {
    // Poll TDLib for updates in a periodic timer
    // In production, this should be in a separate Isolate
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_clientId == null) {
        timer.cancel();
        return;
      }
      _receiveUpdates();
    });
  }

  void _receiveUpdates() {
    final response = TdPlugin.instance.tdReceive(_clientId!);
    if (response == null) return;

    final object = convertJsonToObject(response);
    if (object == null) return;

    // Check if this is a response to a pending invoke
    if (object.extra != null) {
      final completer = _pendingInvokes.remove(object.extra.toString());
      completer?.complete(object);
    }

    // Broadcast update
    _updateController.add(object);

    // Handle authorization state changes
    if (object is td.UpdateAuthorizationState) {
      _handleAuthState(object.authorizationState);
    }
  }

  void _handleAuthState(td.AuthorizationState state) {
    switch (state) {
      case td.AuthorizationStateWaitPhoneNumber():
        _authState = 'waitPhoneNumber';
        break;
      case td.AuthorizationStateWaitCode():
        _authState = 'waitCode';
        break;
      case td.AuthorizationStateWaitPassword():
        _authState = 'waitPassword';
        break;
      case td.AuthorizationStateReady():
        _authState = 'ready';
        _isAuthorized = true;
        break;
      case td.AuthorizationStateClosed():
        _authState = 'closed';
        _isAuthorized = false;
        break;
      default:
        _authState = state.runtimeType.toString();
    }
    _authError = null;
    notifyListeners();
  }

  /// Send a TDLib function and wait for the response
  Future<td.TdObject> invoke(td.TdFunction function) async {
    final extra = DateTime.now().microsecondsSinceEpoch.toString();
    final completer = Completer<td.TdObject>();
    _pendingInvokes[extra] = completer;

    final json = function.toJson();
    json['@extra'] = extra;
    TdPlugin.instance.tdSend(_clientId!, jsonEncode(json));

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingInvokes.remove(extra);
        throw TimeoutException('TDLib invoke timed out');
      },
    );
  }

  // ─── Auth methods ───

  Future<void> sendPhoneNumber(String phone) async {
    try {
      await invoke(td.SetAuthenticationPhoneNumber(
        phoneNumber: phone,
        settings: td.PhoneNumberAuthenticationSettings(
          allowFlashCall: false,
          allowMissedCall: false,
          isCurrentPhoneNumber: false,
          hasUnknownPhoneNumber: false,
          allowSmsRetrieverApi: false,
          firebaseAuthenticationSettings: null,
          authenticationTokens: [],
        ),
      ));
    } catch (e) {
      _authError = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendAuthCode(String code) async {
    try {
      await invoke(td.CheckAuthenticationCode(code: code));
    } catch (e) {
      _authError = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendPassword(String password) async {
    try {
      await invoke(td.CheckAuthenticationPassword(password: password));
    } catch (e) {
      _authError = e.toString();
      notifyListeners();
    }
  }

  // ─── Chat methods ───

  Future<td.TdObject> getChats({int limit = 100}) async {
    return invoke(td.GetChats(
      chatList: null,
      limit: limit,
    ));
  }

  Future<td.TdObject> getChat(int chatId) async {
    return invoke(td.GetChat(chatId: chatId));
  }

  Future<td.TdObject> getChatHistory(
    int chatId, {
    int fromMessageId = 0,
    int limit = 50,
  }) async {
    return invoke(td.GetChatHistory(
      chatId: chatId,
      fromMessageId: fromMessageId,
      offset: 0,
      limit: limit,
      onlyLocal: false,
    ));
  }

  // ─── File methods ───

  Future<td.TdObject> downloadFile(
    int fileId, {
    int priority = 32,
    int offset = 0,
    int limit = 0,
  }) async {
    return invoke(td.DownloadFile(
      fileId: fileId,
      priority: priority,
      offset: offset,
      limit: limit,
      synchronous: false,
    ));
  }

  Future<void> cancelDownload(int fileId) async {
    await invoke(td.CancelDownloadFile(
      fileId: fileId,
      onlyIfPending: false,
    ));
  }

  @override
  void dispose() {
    _updateController.close();
    _clientId = null;
    super.dispose();
  }
}
