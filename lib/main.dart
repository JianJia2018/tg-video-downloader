import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:tg_video_downloader/services/tdlib_service.dart';
import 'package:tg_video_downloader/services/download_manager.dart';
import 'package:tg_video_downloader/services/debug_log_service.dart';
import 'package:tg_video_downloader/features/auth/api_credentials_screen.dart';
import 'package:tg_video_downloader/features/auth/auth_screen.dart';
import 'package:tg_video_downloader/features/auth/init_error_screen.dart';
import 'package:tg_video_downloader/features/channels/channels_screen.dart';
import 'package:tg_video_downloader/widgets/debug_log_fab.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final logger = DebugLogService();
  FlutterError.onError = (details) {
    logger.error('FlutterError', details.exceptionAsString());
    FlutterError.presentError(details);
  };

  runZonedGuarded(
    () {
      logger.info('App', 'Application starting');
      runApp(TgDownloaderApp(logger: logger));
    },
    (error, stack) {
      logger.error('Zone', '$error\n$stack');
    },
  );
}

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class TgDownloaderApp extends StatelessWidget {
  final DebugLogService logger;

  const TgDownloaderApp({super.key, required this.logger});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: logger),
        ChangeNotifierProvider(create: (_) => TdlibService()..logger = logger),
        ChangeNotifierProvider(create: (_) => DownloadManager()),
      ],
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        title: 'TG Downloader',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2AABEE),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2AABEE),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        builder: (context, child) {
          // DebugLogFab disabled due to performance impact
          // - It uses context.select<DebugLogService, int>((s) => s.entryCount)
          // - Every log entry triggers a rebuild at app root level
          // - Combined with TDLib 250ms polling, this causes frequent rebuilds
          return child ?? const SizedBox.shrink();
          // return Stack(
          //   children: [
          //     child ?? const SizedBox.shrink(),
          //     DebugLogFab(navigatorKey: appNavigatorKey),
          //   ],
          // );
        },
        home: const AppRoot(),
      ),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  StreamSubscription<td.TdObject>? _updatesSubscription;

  @override
  void initState() {
    super.initState();
    _listenToTdlibUpdates();
  }

  @override
  void dispose() {
    _updatesSubscription?.cancel();
    super.dispose();
  }

  void _listenToTdlibUpdates() {
    final tdlib = context.read<TdlibService>();
    final downloadManager = context.read<DownloadManager>();

    _updatesSubscription = tdlib.updates.listen((update) {
      if (update is td.UpdateFile) {
        downloadManager.handleFileUpdate(update);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use context.select to only rebuild on specific state changes
    // - context.watch<TdlibService>() rebuilds on ANY notifyListeners() call
    // - TdlibService calls notifyListeners() 9+ times on various events
    // - TDLib polling every 250ms can trigger frequent updates
    final credentialsLoaded = context.select<TdlibService, bool>((s) => s.credentialsLoaded);
    final hasCredentials = context.select<TdlibService, bool>((s) => s.hasCredentials);
    final initError = context.select<TdlibService, String?>((s) => s.initError);
    final isInitialized = context.select<TdlibService, bool>((s) => s.isInitialized);
    final isInitializing = context.select<TdlibService, bool>((s) => s.isInitializing);
    final isAuthorized = context.select<TdlibService, bool>((s) => s.isAuthorized);

    if (!credentialsLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!hasCredentials) {
      return const ApiCredentialsScreen();
    }

    if (initError != null && !isInitialized) {
      return const InitErrorScreen();
    }

    if (isInitializing || !isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!isAuthorized) {
      return const AuthScreen();
    }

    return const ChannelsScreen();
  }
}