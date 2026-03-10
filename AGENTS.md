# AGENTS.md

> Guidelines for AI coding agents working in this repository.

## Project Overview

Flutter Android app for downloading Telegram videos. Uses TDLib (via `handy_tdlib` FFI binding) to authenticate with Telegram and download media files. State management with Provider. Material 3 UI.

**Platform**: Android only (minSdk 24, targetSdk 34)
**Dart SDK**: >=3.2.0 <4.0.0
**Flutter**: 3.27+ stable
**TDLib**: v1.8.36 via `handy_tdlib` package

## Build & Run Commands

```bash
# Install dependencies
flutter pub get

# Build release APK (requires API credentials)
flutter build apk --release \
  --dart-define=TELEGRAM_API_ID=YOUR_ID \
  --dart-define=TELEGRAM_API_HASH=YOUR_HASH

# Build debug APK
flutter build apk --debug \
  --dart-define=TELEGRAM_API_ID=YOUR_ID \
  --dart-define=TELEGRAM_API_HASH=YOUR_HASH

# Run all tests
flutter test

# Run a single test file
flutter test test/app_test.dart

# Run a single test by name
flutter test --name "placeholder test"

# Analyze (lint)
flutter analyze

# Format code
dart format lib/ test/
```

**CI**: GitHub Actions builds on push to `main`, tags matching `v*`, PRs, and manual `workflow_dispatch` runs. See `.github/workflows/build-android.yml`. Release APKs are signed in CI from GitHub Secrets, and pushing a `v*` tag auto-creates a GitHub Release with attached APKs.

## Architecture

```
lib/
├── main.dart                    # Entry point, MultiProvider setup, routing
├── services/
│   ├── tdlib_service.dart       # TDLib client: auth, chat/message APIs, file download
│   └── download_manager.dart    # Download queue, progress tracking, task lifecycle
├── features/
│   ├── auth/auth_screen.dart    # Phone → code → password login flow
│   ├── channels/channels_screen.dart  # Chat list + video message browser
│   └── downloads/downloads_screen.dart  # Active/completed download list
├── core/                        # (reserved) Shared utilities, constants
├── models/                      # (reserved) Data models
└── widgets/                     # (reserved) Reusable UI components
```

**Data flow**: `Flutter UI → Provider (ChangeNotifier) → TdlibService (FFI) → libtdjson.so`

## Key Dependencies

| Package | Purpose |
|---|---|
| `handy_tdlib` | TDLib v1.8.36 FFI binding (Android only) |
| `provider` | State management (ChangeNotifier pattern) |
| `path_provider` | Platform-specific file paths |
| `permission_handler` | Runtime permissions (storage, notifications) |
| `shared_preferences` | Local key-value persistence |
| `flutter_local_notifications` | Download completion notifications |
| `percent_indicator` | Progress bar widgets |
| `intl` | Number/date formatting |

## Code Style

### Formatting & Linting
- Linter: `package:flutter_lints/flutter.yaml` (see `analysis_options.yaml`)
- `prefer_const_constructors: true` — always use `const` where possible
- `prefer_const_declarations: true` — prefer `const` over `final` for compile-time constants
- `avoid_print: false` — print statements allowed (used for TDLib debug logging)
- Run `dart format lib/ test/` before committing

### Imports
- Import `handy_tdlib` with a prefix to avoid name clashes with `dart:io`:
  ```dart
  import 'package:handy_tdlib/api.dart' as td;
  ```
- Group imports: dart core → package → relative, separated by blank lines
- Use package imports (`package:tg_video_downloader/...`), not relative paths

### Naming Conventions
- Files: `snake_case.dart`
- Classes: `PascalCase` (e.g., `TdlibService`, `DownloadManager`, `AuthScreen`)
- Variables/methods: `camelCase`
- Private members: prefix with `_` (e.g., `_clientId`, `_isInitialized`)
- Constants: `camelCase` (e.g., `const seedColor = Color(0xFF2AABEE)`)
- Feature folders: `lib/features/<feature_name>/`

### State Management Pattern
- Services extend `ChangeNotifier` and call `notifyListeners()` on state changes
- Prefer `Selector` / `context.select<T, R>()` for high-frequency or list-heavy UI to localize rebuilds
- Use `context.watch<T>()` only when the whole widget genuinely depends on the full service state
- Widgets use `context.read<T>()` for one-shot actions (button handlers)
- Providers registered in `main.dart` via `MultiProvider`

### TDLib Patterns
- TDLib currently runs on the main isolate with batched polling via `Timer.periodic(250ms)`
- Polling drains multiple pending TDLib updates per tick to reduce UI-isolate wakeups under load
- Invoke/response correlation via `extra` field (microsecond timestamps as string keys)
- Use `Completer<td.TdObject>` for async invoke → response pattern
- Auth state handled via sealed class switch: `AuthorizationStateWaitPhoneNumber`, etc.
- Download progress tracked via `UpdateFile` events from TDLib update stream
- All TDLib types use `td.` prefix (e.g., `td.DownloadFile`, `td.UpdateFile`)

### Error Handling
- TDLib errors: check for `td.Error` type in invoke responses
- UI errors: display via `ScaffoldMessenger.of(context).showSnackBar()`
- Service errors: catch and store in state, expose via getter for UI to display
- Never silently swallow errors in TDLib callbacks

### Widget Patterns
- Screens are `StatefulWidget` when managing local UI state (text controllers, loading flags)
- Screens are `StatelessWidget` when purely driven by Provider state
- Use `Card` with `ListTile` for list items
- Use `LinearProgressIndicator` for download progress
- Material 3 with `ColorScheme.fromSeed()`, support both light and dark themes

## Android Configuration

- **Namespace**: `com.tgdownloader.app`
- **Min SDK**: 24 (Android 7.0)
- **Target SDK**: 34 (Android 14)
- **Signing**: Release builds use keystore from `android/key.properties` (generated from GitHub Secrets in CI)
- **ProGuard**: Enabled for release. TDLib classes preserved in `android/app/proguard-rules.pro`
- **Permissions**: INTERNET, storage (scoped for SDK 29+, READ_MEDIA_VIDEO for 33+), FOREGROUND_SERVICE, POST_NOTIFICATIONS

## Testing

Tests live in `test/` mirroring `lib/` structure. Currently minimal (placeholder).

```bash
flutter test                           # Run all
flutter test test/app_test.dart        # Single file
flutter test --name "test name"        # Single test by name
```

When adding tests:
- Unit tests for services (`tdlib_service`, `download_manager`)
- Widget tests for screens (use `WidgetTester`)
- Mock TDLib responses — never call real Telegram API in tests

## CI/CD Notes

- Flutter version pinned to `3.27.0` in CI
- Java 17 (Zulu) for Android Gradle builds
- Workflow triggers on:
  - push to `main`
  - push tags matching `v*` (example: `v0.0.9`)
  - pull requests targeting `main`
  - manual `workflow_dispatch`
- For tag builds, CI derives `BUILD_NAME` from the tag by stripping the leading `v` (example: `v0.0.9` → `0.0.9`)
- For manual runs with `create_release=true`, `release_tag` is used as the GitHub Release tag/name, and CI also strips a leading `v` when deriving the Android `build-name`
- Release build command in CI is split-per-ABI for `android-arm` and `android-arm64`
- Secrets required by the current workflow: `TELEGRAM_API_ID`, `TELEGRAM_API_HASH`, `KEYSTORE_BASE64`, `PASSWORD`
- CI writes `android/key.properties` with fixed `keyAlias=release` and uses the same `PASSWORD` secret for both `storePassword` and `keyPassword`
- APK artifacts retained 30 days
- Tagging with `v*` auto-creates a GitHub Release and uploads:
  - `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
  - `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- If the release is driven purely by a tag, `pubspec.yaml` does not need to be manually bumped for CI to stamp the APK with the matching version; CI derives that from the tag itself
