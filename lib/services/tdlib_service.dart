import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:handy_tdlib/client.dart';
import 'package:handy_tdlib/handy_tdlib.dart' show convertJsonToObject;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tg_video_downloader/services/debug_log_service.dart';
import 'package:tg_video_downloader/services/tdlib_isolate_service.dart';

/// Core TDLib service — manages client lifecycle, auth, and API calls.
///
/// Uses two Dart Isolates:
///   - Invokes isolate: sends requests to TDLib
///   - Updates isolate: receives responses and updates from TDLib
class TdlibService extends ChangeNotifier {
  static bool _pluginInitialized = false;
  static const _updatePollInterval = Duration(milliseconds: 250);
  static const _optionBatchSize = 10;
  static const _maxUpdatesPerDrain = 24;
  static const _prefsApiIdKey = 'telegram_api_id';
  static const _prefsApiHashKey = 'telegram_api_hash';
  int? _clientId;
  int? _apiId;
  String? _apiHash;
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isAuthorized = false;
  bool _credentialsLoaded = false;
  DebugLogService? logger;
  Timer? _updatesTimer;
  Timer? _storageOptimizationTimer;
  bool _isDrainingUpdates = false;

  // Isolate service for background updates
  final TdlibIsolateService _isolateService = TdlibIsolateService();

  // Auth state
  String _authState = 'initial';
  String? _authError;
  String? _initError;

  // Stream controller for TDLib updates
  final _updateController = StreamController<td.TdObject>.broadcast();
  Stream<td.TdObject> get updates => _updateController.stream;

  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  bool get isAuthorized => _isAuthorized;
  bool get credentialsLoaded => _credentialsLoaded;
  bool get hasCredentials => _apiId != null && (_apiHash?.isNotEmpty ?? false);
  String get authState => _authState;
  String? get authError => _authError;
  String? get initError => _initError;
  int? get clientId => _clientId;

  // Pending invoke completers keyed by 'extra' field
  final Map<String, Completer<td.TdObject>> _pendingInvokes = {};

  TdlibService() {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final storedApiId = prefs.getInt(_prefsApiIdKey);
    final storedApiHash = prefs.getString(_prefsApiHashKey);

    _apiId = storedApiId;
    _apiHash = storedApiHash;
    _credentialsLoaded = true;
    logger?.info('TDLib', 'Credential bootstrap finished. hasCredentials=$hasCredentials');
    notifyListeners();

    if (hasCredentials) {
      await configureAndInit(
        apiId: _apiId!,
        apiHash: _apiHash!,
        persist: false,
      );
    }
  }

  Future<void> configureAndInit({
    required int apiId,
    required String apiHash,
    bool persist = true,
  }) async {
    if (_isInitializing) {
      return;
    }

    _apiId = apiId;
    _apiHash = apiHash;
    _initError = null;
    _authError = null;
    _isInitializing = true;
    _isInitialized = false;
    _isAuthorized = false;
    _authState = 'initial';
    _updatesTimer?.cancel();
    _clientId = null;
    notifyListeners();

    try {
      if (persist) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefsApiIdKey, apiId);
        await prefs.setString(_prefsApiHashKey, apiHash);
      }

      if (!_pluginInitialized) {
        logger?.info('TDLib', 'Initializing TdPlugin');
        await TdPlugin.initialize();
        _pluginInitialized = true;
        logger?.info('TDLib', 'TdPlugin initialized');
      }

      logger?.info('TDLib', 'Creating TDLib client');
      _clientId = TdPlugin.instance.tdCreateClientId();

      _startUpdatesListener();
      logger?.info('TDLib', 'Updates listener started');

      final appDir = await getApplicationDocumentsDirectory();
      logger?.info('TDLib', 'Sending SetTdlibParameters');
      final response = await invoke(td.SetTdlibParameters(
        useTestDc: false,
        apiId: apiId,
        apiHash: apiHash,
        databaseDirectory: '${appDir.path}/tdlib',
        filesDirectory: '${appDir.path}/tdlib_files',
        useMessageDatabase: true,
        useFileDatabase: true,
        useChatInfoDatabase: true,
        useSecretChats: false,
        systemLanguageCode: 'en',
        deviceModel: 'Android',
        applicationVersion: '0.0.9',
        systemVersion: 'Android',
        databaseEncryptionKey: '',
      ));

      if (response is td.TdError) {
        throw Exception('TDLib init error ${response.code}: ${response.message}');
      }

      await _configurePerformanceOptions();

      _isInitialized = true;
      _startStorageOptimization();
      await _configurePerformanceOptions();

      _isInitialized = true;
      _startStorageOptimization();
      await _configurePerformanceOptions();

      _isInitialized = true;
      _isInitializing = false;
      logger?.info('TDLib', 'Initialization finished');
      notifyListeners();
    } catch (e, stack) {
      _isInitializing = false;
      _initError = e.toString();
      logger?.error('TDLib', 'Initialization failed: $e\n$stack');
      notifyListeners();
    }
  }

  Future<void> retryInitialization() async {
    if (!hasCredentials) {
      return;
    }
    await configureAndInit(apiId: _apiId!, apiHash: _apiHash!, persist: false);
  }

  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsApiIdKey);
    await prefs.remove(_prefsApiHashKey);

    _apiId = null;
    _apiHash = null;
    _updatesTimer?.cancel();
    _clientId = null;
    _isInitialized = false;
    _isInitializing = false;
    _isAuthorized = false;
    _initError = null;
    _authError = null;
    _authState = 'initial';
    notifyListeners();
  }

  /// Configure TDLib performance options for better resource usage
  Future<void> _configurePerformanceOptions() async {
    try {
      logger?.info('TDLib', 'Configuring performance options');

      // Reduce message memory cache time (default 60s for users, 1800s for bots)
      await _setOption('message_unload_delay', 60);

      // Enable storage optimizer
      await _setOption('use_storage_optimizer', true);

      // Disable network statistics to reduce disk I/O
      await _setOption('disable_network_statistics', true);
      await _setOption('disable_persistent_network_statistics', true);

      // Disable time adjustment protection to reduce disk usage
      await _setOption('disable_time_adjustment_protection', true);

      // Disable top chats statistics
      await _setOption('disable_top_chats', true);

      // Ignore inline thumbnails if not displaying message previews
      await _setOption('ignore_inline_thumbnails', true);

      // Prefer IPv6 for potentially better performance
      await _setOption('prefer_ipv6', true);

      logger?.info('TDLib', 'Performance options configured successfully');
    } catch (e) {
      // Log but don't fail initialization if option setting fails
      logger?.warning('TDLib', 'Some performance options failed: $e');
    }
  }

  /// Helper to set a TDLib option with proper error handling
  Future<void> _setOption(String name, dynamic value) async {
    try {
      final optionValue = value is bool
          ? td.OptionValueBoolean(value: value)
          : td.OptionValueInteger(value: value as int);

      final response = await invoke(td.SetOption(name: name, value: optionValue));

      if (response is td.TdError) {
        logger?.warning('TDLib', 'Failed to set option $name: ${response.message}');
      }
    } catch (e) {
      logger?.warning('TDLib', 'Exception setting option $name: $e');
    }
  }

  void _startUpdatesListener() {
    // Poll TDLib in batches to reduce frequent UI-isolate wakeups.
    _updatesTimer?.cancel();
    _updatesTimer = Timer.periodic(_updatePollInterval, (timer) {
      if (_clientId == null) {
        timer.cancel();
        return;
      }
      _drainUpdates();
    });
  }

  void _drainUpdates() {
    if (_isDrainingUpdates) {
      return;
    }

    _isDrainingUpdates = true;
    try {
      var processed = 0;
      while (processed < _maxUpdatesPerDrain && _receiveSingleUpdate()) {
        processed++;
      }

      if (processed == _maxUpdatesPerDrain) {
        scheduleMicrotask(_drainUpdates);
      }
    } finally {
      _isDrainingUpdates = false;
    }
  }

  bool _receiveSingleUpdate() {
    final response = TdPlugin.instance.tdReceive();
    if (response == null) {
      return false;
    }

    final object = convertJsonToObject(response);
    if (object == null) {
      return true;
    }

    // Check if this is a response to a pending invoke
    if (object.extra != null) {
      final completer = _pendingInvokes.remove(object.extra.toString());
      completer?.complete(object);
    }

    // Broadcast update
    _updateController.add(object);

    // Handle authorization state changes
    if (object is td.UpdateAuthorizationState) {
      logger?.info('TDLib', 'Authorization state update: ${object.authorizationState.runtimeType}');
      _handleAuthState(object.authorizationState);
    }

    return true;
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
    logger?.info('TDLib', 'Invoke sent: ${function.runtimeType}');

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingInvokes.remove(extra);
        logger?.error('TDLib', 'Invoke timed out: ${function.runtimeType}');
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
      logger?.error('Auth', 'Phone number submit failed: $e');
      _authError = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendAuthCode(String code) async {
    try {
      await invoke(td.CheckAuthenticationCode(code: code));
    } catch (e) {
      logger?.error('Auth', 'Auth code submit failed: $e');
      _authError = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendPassword(String password) async {
    try {
      await invoke(td.CheckAuthenticationPassword(password: password));
    } catch (e) {
      logger?.error('Auth', 'Password submit failed: $e');
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

  // ─── Storage optimization ───

  /// Start periodic storage optimization (daily)
  void _startStorageOptimization() {
    _storageOptimizationTimer?.cancel();
    // Run every 24 hours
    _storageOptimizationTimer = Timer.periodic(const Duration(hours: 24), (_) {
      optimizeStorage();
    });

    // Run initial optimization after a short delay
    Future.delayed(const Duration(minutes: 5), () {
      optimizeStorage();
    });
  }

  /// Optimize storage to free up disk space
  Future<void> optimizeStorage() async {
    if (_clientId == null) return;

    try {
      logger?.info('TDLib', 'Starting storage optimization');

      final response = await invoke(td.OptimizeStorage(
        fileTypes: [],            // Default: all types except thumbnails, profile photos, stickers and wallpapers
        size: 100 * 1024 * 1024, // 100 MB limit
        ttl: 7 * 24 * 60 * 60,    // 7 days
        count: -1,                 // No limit on file count
        immunityDelay: 3600,       // 1 hour immunity
        returnDeletedFileStatistics: false,
      ));

      if (response is td.TdError) {
        logger?.warning('TDLib', 'Storage optimization returned error: ${response.message}');
      } else {
        logger?.info('TDLib', 'Storage optimization completed');
      }
    } catch (e) {
      logger?.warning('TDLib', 'Storage optimization failed: $e');
    }
  }

  @override
  void dispose() {
    _updatesTimer?.cancel();
    _storageOptimizationTimer?.cancel();
    _updateController.close();
    _clientId = null;
    super.dispose();
  }
}