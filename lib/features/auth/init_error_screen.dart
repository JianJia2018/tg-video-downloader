import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tg_video_downloader/services/tdlib_service.dart';

class InitErrorScreen extends StatelessWidget {
  const InitErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tdlib = context.watch<TdlibService>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 72,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Initialization failed',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tdlib.initError ?? 'Unknown initialization error',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: tdlib.isInitializing ? null : tdlib.retryInitialization,
                    child: const Text('Retry initialization'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: tdlib.isInitializing ? null : tdlib.clearCredentials,
                    child: const Text('Change API credentials'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
