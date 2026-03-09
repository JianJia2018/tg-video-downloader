import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tg_video_downloader/services/tdlib_service.dart';
import 'package:tg_video_downloader/services/download_manager.dart';
import 'package:tg_video_downloader/features/auth/auth_screen.dart';
import 'package:tg_video_downloader/features/channels/channels_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TgDownloaderApp());
}

class TgDownloaderApp extends StatelessWidget {
  const TgDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TdlibService()),
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

    if (!tdlib.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!tdlib.isAuthorized) {
      return const AuthScreen();
    }

    return const ChannelsScreen();
  }
}
