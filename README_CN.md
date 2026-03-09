**中文** | [English](./README.md)

# TG Video Downloader

基于 Flutter 的 Android 应用，用于从 Telegram 频道和聊天中下载视频，底层使用 [TDLib](https://github.com/tdlib/td)。

## 功能

- 使用 Telegram 账号登录（手机号 + 验证码 + 两步验证）
- 浏览频道、群组和聊天
- 列出视频消息及元信息（分辨率、时长、文件大小）
- 实时进度追踪的视频下载
- 下载队列管理（取消、删除）
- Material 3 界面，支持深色模式

## 架构

```
Flutter UI → Provider（状态管理）→ TdlibService（Dart FFI）→ libtdjson.so（TDLib）
                                → DownloadManager（下载队列 + 进度追踪）
```

| 层级 | 技术 |
|---|---|
| 界面 | Flutter + Material 3 |
| 状态管理 | Provider |
| Telegram API | handy_tdlib（TDLib v1.8.36，FFI 绑定） |
| 平台 | 仅 Android（minSdk 24） |

## 构建

### 前置条件

1. 在 [my.telegram.org](https://my.telegram.org) 获取 Telegram API 凭证
2. 生成 Release 签名密钥：

```bash
keytool -genkey -v -keystore release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias release
```

### GitHub Actions 构建（推荐）

本项目设计为完全在 CI 中构建，**无需本地安装 Flutter 或 Android SDK**。

1. Fork 或 push 本仓库到 GitHub
2. 进入 **Settings → Secrets and variables → Actions**
3. 添加以下仓库密钥：

| 密钥名 | 值 |
|---|---|
| `TELEGRAM_API_ID` | 你的 Telegram api_id |
| `TELEGRAM_API_HASH` | 你的 Telegram api_hash |
| `KEYSTORE_BASE64` | `base64 -i release-key.jks` 的输出 |
| `KEYSTORE_PASSWORD` | 密钥库密码 |
| `KEY_ALIAS` | `release`（或你自定义的别名） |
| `KEY_PASSWORD` | 密钥密码 |

4. 推送到 `main` 分支 — GitHub Actions 自动构建 APK
5. 在 **Actions → Build Android APK → Artifacts** 下载 APK

### 发布 Release

打 tag 自动创建 GitHub Release 并附带 APK：

```bash
git tag v0.1.0
git push origin v0.1.0
```

### 本地构建（如已安装 Flutter SDK）

```bash
flutter pub get
flutter build apk --release \
  --dart-define=TELEGRAM_API_ID=你的ID \
  --dart-define=TELEGRAM_API_HASH=你的HASH
```

## 项目结构

```
lib/
├── main.dart                          # 应用入口
├── services/
│   ├── tdlib_service.dart             # TDLib 客户端封装
│   └── download_manager.dart          # 下载队列与进度管理
├── features/
│   ├── auth/
│   │   └── auth_screen.dart           # 登录流程界面
│   ├── channels/
│   │   └── channels_screen.dart       # 聊天列表 + 视频浏览
│   └── downloads/
│       └── downloads_screen.dart      # 下载管理界面
```

## 技术栈

- **Flutter** 3.27+，Dart 3.2+
- **handy_tdlib** — TDLib v1.8.36 的 Android FFI 绑定
- **Provider** — 状态管理
- **Material 3** — 现代 Android 界面规范

## 开发计划

- [ ] 后台下载服务（Dart Isolate）
- [ ] 视频缩略图预览
- [ ] 聊天内搜索
- [ ] 批量下载（多选视频）
- [ ] 下载速度显示
- [ ] 下载完成通知
- [ ] 自定义保存目录

## 致谢

- [TDLib](https://github.com/tdlib/td) — Telegram Database Library
- [handy_tdlib](https://pub.dev/packages/handy_tdlib) — Flutter TDLib 插件
- 灵感来源于 [iyear/tdl](https://github.com/iyear/tdl) 和 [jarvis2f/telegram-files](https://github.com/jarvis2f/telegram-files)

## 开源协议

MIT
