[中文](./README_CN.md) | **English**

# TG Video Downloader

A Flutter-based Android app for downloading videos from Telegram channels and chats, powered by [TDLib](https://github.com/tdlib/td).

## Features

- Login with Telegram account (phone + verification code + 2FA)
- Browse channels, groups, and chats
- List video messages with metadata (resolution, duration, file size)
- Download videos with real-time progress tracking
- Download queue management (cancel, remove)
- Material 3 UI with dark mode support

## Architecture

```
Flutter UI → Provider (State) → TdlibService (Dart FFI) → libtdjson.so (TDLib)
                              → DownloadManager (Queue + Progress)
```

| Layer | Tech |
|---|---|
| UI | Flutter + Material 3 |
| State | Provider |
| Telegram API | handy_tdlib (TDLib v1.8.36 via FFI) |
| Platform | Android only (minSdk 24) |

## Build

### Prerequisites

1. Get Telegram API credentials from [my.telegram.org](https://my.telegram.org)
2. Generate a release keystore:

```bash
keytool -genkey -v -keystore release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias release
```

### GitHub Actions (Recommended)

This project is designed to build entirely in CI — no local Flutter/Android SDK required.

1. Fork or push this repo to GitHub
2. Go to **Settings → Secrets and variables → Actions**
3. Add these repository secrets:

| Secret | Value |
|---|---|
| `TELEGRAM_API_ID` | Your Telegram api_id |
| `TELEGRAM_API_HASH` | Your Telegram api_hash |
| `KEYSTORE_BASE64` | Base64 content of `release-key.jks` |
| `PASSWORD` | The single password used for both the keystore and key |

Notes:
- `KEYSTORE_BASE64` is still required for release signing. It contains the actual keystore file.
- `KEY_ALIAS` is fixed to `release` in CI, so you do not need a separate secret for it.
- `PASSWORD` is used for both `storePassword` and `keyPassword`, so generate your keystore with the same password for both.
- If you want the simplest setup, create the keystore with alias `release`.

4. Push to `main` branch — GitHub Actions builds the APK automatically
5. Download APK from **Actions → Build Android APK → Artifacts**

### Creating a Release

Tag a version to auto-publish a GitHub Release with the APK:

```bash
git tag v0.1.0
git push origin v0.1.0
```

### Local Build (if Flutter SDK is installed)

```bash
flutter pub get
flutter build apk --release \
  --dart-define=TELEGRAM_API_ID=YOUR_ID \
  --dart-define=TELEGRAM_API_HASH=YOUR_HASH
```

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── services/
│   ├── tdlib_service.dart             # TDLib client wrapper
│   └── download_manager.dart          # Download queue & progress
├── features/
│   ├── auth/
│   │   └── auth_screen.dart           # Login flow UI
│   ├── channels/
│   │   └── channels_screen.dart       # Chat list + video browser
│   └── downloads/
│       └── downloads_screen.dart      # Download manager UI
```

## Tech Stack

- **Flutter** 3.27+ with Dart 3.2+
- **handy_tdlib** — TDLib v1.8.36 FFI binding for Android
- **Provider** — State management
- **Material 3** — Modern Android UI

## Roadmap

- [ ] Background download service (Dart Isolate)
- [ ] Video thumbnail preview
- [ ] Search within chats
- [ ] Batch download (select multiple videos)
- [ ] Download speed display
- [ ] Notification for completed downloads
- [ ] Save to custom directory

## Credits

- [TDLib](https://github.com/tdlib/td) — Telegram Database Library
- [handy_tdlib](https://pub.dev/packages/handy_tdlib) — Flutter TDLib plugin
- Inspired by [iyear/tdl](https://github.com/iyear/tdl) and [jarvis2f/telegram-files](https://github.com/jarvis2f/telegram-files)

## License

MIT
