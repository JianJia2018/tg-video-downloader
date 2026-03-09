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
| `KEYSTORE_BASE64` | `release-key.jks` 的 Base64 内容 |
| `PASSWORD` | 同时用于 keystore 和 key 的单一密码 |

说明：
- 如果是从 GitHub Actions 页面手动运行 workflow，用户可以直接填写 `telegram_api_id` 和 `telegram_api_hash` 输入项。本次构建会优先使用页面输入，而不是仓库 secret。
- 如果是普通的 push/tag 自动构建，workflow 仍然会回退使用仓库中的 `TELEGRAM_API_ID` 和 `TELEGRAM_API_HASH`。
- `KEYSTORE_BASE64` 仍然必须保留，因为它就是 Release 签名所需的 keystore 文件本体。
- `KEY_ALIAS` 在 CI 中固定为 `release`，所以不再需要单独的 secret。
- `PASSWORD` 同时作为 `storePassword` 和 `keyPassword`，因此生成 keystore 时建议两者设置为同一个密码。
- 如果你想要最简单的配置，生成 keystore 时把 alias 也设置成 `release`。

### 在 Actions 页面使用自己的 Telegram 凭证构建

1. 打开 **Actions → Build Android APK**
2. 点击 **Run workflow**
3. 填写：
   - `telegram_api_id`
   - `telegram_api_hash`
4. 启动构建

这样每个用户都可以用自己的 Telegram API 凭证生成 APK，而不是固定使用仓库拥有者的凭证。

## 为什么 APK 很大，以及现在的分包方式

这个项目使用了 TDLib 以及其他 Android 原生库，所以如果构建的是一个 **universal APK**，它会把多个 CPU 架构一起打进去，体积就会明显变大。

现在 GitHub Actions 已经改成按 **ABI 分包**，会生成：

- `app-armeabi-v7a-release.apk`
- `app-arm64-v8a-release.apk`

现在 CI 默认会跳过 `x86_64`，以便加快发布构建速度，因为真实手机通常只需要 `armeabi-v7a` 或 `arm64-v8a`。如果以后你需要专门给模拟器使用的 APK，再把 `x86_64` 打开即可。

推荐下载：

- 大多数新安卓手机：**`arm64-v8a`**
- 老一点的 32 位设备：**`armeabi-v7a`**
- 模拟器或部分特殊设备：需要时单独构建 `x86_64` APK

所以你之前看到的 123MB，主要就是因为当时打的是把所有原生架构都打进去的通用 APK。

## App 内调试日志与一键分享

应用右下角带有一个悬浮调试按钮。

- 点击后可打开 **Debug Logs** 页面
- 可以使用 **Copy** 复制全部日志
- 可以使用 **Share** 调起 Android 系统分享面板

分享是通过系统分享面板完成的，因此日志可以发送到：

- Telegram / 微信 / 邮件
- 笔记类应用
- Nearby Share
- 任何支持接收文本分享的已安装应用

这和“应用自己在局域网里开一个网页日志服务”不是一回事。如果你想要真正通过浏览器在局域网访问日志，还需要额外实现本地 HTTP server 功能。

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
