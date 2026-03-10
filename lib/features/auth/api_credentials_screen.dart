import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tg_video_downloader/services/tdlib_service.dart';

class ApiCredentialsScreen extends StatefulWidget {
  const ApiCredentialsScreen({super.key});

  @override
  State<ApiCredentialsScreen> createState() => _ApiCredentialsScreenState();
}

class _ApiCredentialsScreenState extends State<ApiCredentialsScreen> {
  final _apiIdController = TextEditingController();
  final _apiHashController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _apiIdController.dispose();
    _apiHashController.dispose();
    super.dispose();
  }

  Future<void> _submit(TdlibService tdlib) async {
    final apiIdText = _apiIdController.text.trim();
    final apiHash = _apiHashController.text.trim();
    final apiId = int.tryParse(apiIdText);

    if (apiId == null || apiHash.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid API ID and API Hash')),
      );
      return;
    }

    setState(() => _submitting = true);
    await tdlib.configureAndInit(apiId: apiId, apiHash: apiHash);
    if (mounted) {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tdlib = context.watch<TdlibService>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.key_outlined,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Enter your Telegram API credentials',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This app uses your own Telegram API ID and API Hash. They are stored only on this device before TDLib starts.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _apiIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Telegram API ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apiHashController,
                    decoration: const InputDecoration(
                      labelText: 'Telegram API Hash',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.password_outlined),
                    ),
                  ),
                  if (tdlib.initError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      tdlib.initError!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _submitting || tdlib.isInitializing
                        ? null
                        : () => _submit(tdlib),
                    child: _submitting || tdlib.isInitializing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save and initialize'),
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
