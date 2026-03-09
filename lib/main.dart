import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tg_video_downloader/services/tdlib_service.dart';
import 'package:tg_video_downloader/services/download_manager.dart';
import 'package:tg_video_downloader/services/debug_log_service.dart';
import 'package:tg_video_downloader/features/auth/auth_screen.dart';
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
          return Stack(
            children: [
              child ?? const SizedBox.shrink(),
              const DebugLogFab(),
            ],
          );
        },
        home: const AppRoot(),
      ),
    );
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final tdlib = context.watch<TdlibService>();
    final logger = context.read<DebugLogService>();

    if (!tdlib.isInitialized) {
      logger.info('AppRoot', 'Waiting for TDLib initialization');
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!tdlib.isAuthorized) {
      logger.info('AppRoot', 'TDLib initialized, waiting for authorization');
      return const AuthScreen();
    }

    logger.info('AppRoot', 'Authorization ready, opening channels screen');
    return const ChannelsScreen();
  }
}
