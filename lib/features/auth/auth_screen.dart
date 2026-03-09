import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tg_video_downloader/services/debug_log_service.dart';
import 'package:tg_video_downloader/services/tdlib_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tdlib = context.watch<TdlibService>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.telegram,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'TG Downloader',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getSubtitle(tdlib.authState),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: _getInputLabel(tdlib.authState),
                  hintText: _getInputHint(tdlib.authState),
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(_getInputIcon(tdlib.authState)),
                ),
                keyboardType: _getKeyboardType(tdlib.authState),
                obscureText: tdlib.authState == 'waitPassword',
                onSubmitted: (_) => _submit(tdlib),
              ),
              if (tdlib.authError != null) ...[
                const SizedBox(height: 8),
                Text(
                  tdlib.authError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isLoading ? null : () => _submit(tdlib),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_getButtonText(tdlib.authState)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(TdlibService tdlib) async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;

    final logger = context.read<DebugLogService>();
    logger.info('Auth', 'Submitting auth step: ${tdlib.authState}');

    setState(() => _isLoading = true);

    switch (tdlib.authState) {
      case 'waitPhoneNumber':
        await tdlib.sendPhoneNumber(value);
        break;
      case 'waitCode':
        await tdlib.sendAuthCode(value);
        break;
      case 'waitPassword':
        await tdlib.sendPassword(value);
        break;
    }

    logger.info('Auth', 'Finished auth step: ${tdlib.authState}');
    _controller.clear();
    setState(() => _isLoading = false);
  }

  String _getSubtitle(String state) => switch (state) {
        'waitPhoneNumber' => 'Enter your phone number to sign in',
        'waitCode' => 'Enter the verification code sent to your device',
        'waitPassword' => 'Enter your two-factor authentication password',
        _ => 'Connecting to Telegram...',
      };

  String _getInputLabel(String state) => switch (state) {
        'waitPhoneNumber' => 'Phone Number',
        'waitCode' => 'Verification Code',
        'waitPassword' => 'Password',
        _ => '',
      };

  String _getInputHint(String state) => switch (state) {
        'waitPhoneNumber' => '+1234567890',
        'waitCode' => '12345',
        'waitPassword' => 'Your 2FA password',
        _ => '',
      };

  IconData _getInputIcon(String state) => switch (state) {
        'waitPhoneNumber' => Icons.phone,
        'waitCode' => Icons.sms,
        'waitPassword' => Icons.lock,
        _ => Icons.hourglass_empty,
      };

  TextInputType _getKeyboardType(String state) => switch (state) {
        'waitPhoneNumber' => TextInputType.phone,
        'waitCode' => TextInputType.number,
        _ => TextInputType.text,
      };

  String _getButtonText(String state) => switch (state) {
        'waitPhoneNumber' => 'Send Code',
        'waitCode' => 'Verify',
        'waitPassword' => 'Sign In',
        _ => 'Please wait...',
      };
}
