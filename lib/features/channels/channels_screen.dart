import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:tg_video_downloader/services/tdlib_service.dart';
import 'package:tg_video_downloader/services/download_manager.dart';
import 'package:tg_video_downloader/services/debug_log_service.dart';
import 'package:tg_video_downloader/features/channels/detail_screen.dart';
import 'package:tg_video_downloader/features/downloads/downloads_screen.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  List<td.Chat> _chats = [];
  bool _isLoading = true;
  ChatGroupFilter _filter = ChatGroupFilter.all;

  List<td.Chat> get _filteredChats {
    return switch (_filter) {
      ChatGroupFilter.all => _chats,
      ChatGroupFilter.channels => _chats
          .where(
            (chat) => chat.type is td.ChatTypeSupergroup &&
                (chat.type as td.ChatTypeSupergroup).isChannel,
          )
          .toList(),
      ChatGroupFilter.groups => _chats
          .where(
            (chat) => chat.type is td.ChatTypeBasicGroup ||
                (chat.type is td.ChatTypeSupergroup &&
                    !(chat.type as td.ChatTypeSupergroup).isChannel),
          )
          .toList(),
      ChatGroupFilter.privateChats => _chats
          .where((chat) => chat.type is td.ChatTypePrivate)
          .toList(),
    };
  }

  @override
  void initState() {
    super.initState();
    _loadChats();
    // Attach download manager to tdlib service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tdlib = context.read<TdlibService>();
      tdlib.logger = context.read<DebugLogService>();
      final dm = context.read<DownloadManager>();
      dm.attachTdlib(tdlib);
      context.read<DebugLogService>().info('Channels', 'Attached download manager and debug logger');
    });
  }

  Future<void> _loadChats() async {
    final tdlib = context.read<TdlibService>();
    final logger = context.read<DebugLogService>();
    try {
      logger.info('Channels', 'Loading chats');
      final result = await tdlib.getChats(limit: 100);
      if (result is td.Chats) {
        final chats = <td.Chat>[];
        for (final chatId in result.chatIds) {
          final chatResult = await tdlib.getChat(chatId);
          if (chatResult is td.Chat) {
            chats.add(chatResult);
          }
        }
        setState(() {
          _chats = chats;
          _isLoading = false;
        });
        logger.info('Channels', 'Loaded ${chats.length} chats');
      }
    } catch (e) {
      logger.error('Channels', 'Failed to load chats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TG Downloader'),
        actions: [
          Selector<DownloadManager, int>(
            selector: (_, manager) => manager.activeTasks.length,
            builder: (context, activeCount, _) {
              final button = IconButton(
                icon: const Icon(Icons.download),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                ),
              );

              if (activeCount == 0) {
                return button;
              }

              return Badge(
                label: Text('$activeCount'),
                child: button,
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ChatGroupFilter>(
                      segments: const [
                        ButtonSegment(
                          value: ChatGroupFilter.all,
                          label: Text('All'),
                          icon: Icon(Icons.apps_outlined),
                        ),
                        ButtonSegment(
                          value: ChatGroupFilter.channels,
                          label: Text('Channels'),
                          icon: Icon(Icons.campaign_outlined),
                        ),
                        ButtonSegment(
                          value: ChatGroupFilter.groups,
                          label: Text('Groups'),
                          icon: Icon(Icons.group_outlined),
                        ),
                        ButtonSegment(
                          value: ChatGroupFilter.privateChats,
                          label: Text('Private'),
                          icon: Icon(Icons.person_outline),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _filter = selection.first;
                        });
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredChats.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  size: 64, color: theme.colorScheme.outline),
                              const SizedBox(height: 16),
                              Text('No chats found in this group',
                                  style: theme.textTheme.titleMedium),
                              const SizedBox(height: 8),
                              FilledButton.tonal(
                                onPressed: () {
                                  setState(() => _isLoading = true);
                                  _loadChats();
                                },
                                child: const Text('Refresh'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadChats,
                          child: ListView.builder(
                            itemCount: _filteredChats.length,
                            itemBuilder: (context, index) {
                              final chat = _filteredChats[index];
                              return _ChatTile(chat: chat);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

enum ChatGroupFilter { all, channels, groups, privateChats }

class _ChatTile extends StatelessWidget {
  final td.Chat chat;
  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isChannel = chat.type is td.ChatTypeSupergroup;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          isChannel ? Icons.campaign : Icons.group,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        chat.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _getChatTypeLabel(chat.type),
        style: theme.textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailScreen(chat: chat),
          ),
        );
      },
    );
    );
  }

  String _getChatTypeLabel(td.ChatType type) => switch (type) {
        td.ChatTypeSupergroup(isChannel: true) => 'Channel',
        td.ChatTypeSupergroup() => 'Supergroup',
        td.ChatTypeBasicGroup() => 'Group',
        td.ChatTypePrivate() => 'Private',
        _ => 'Chat',
      };
}

/// Shows video messages from a chat, allowing user to download them
class _ChatMediaScreen extends StatefulWidget {
  final td.Chat chat;
  const _ChatMediaScreen({required this.chat});

  @override
  State<_ChatMediaScreen> createState() => _ChatMediaScreenState();
}

class _ChatMediaScreenState extends State<_ChatMediaScreen> {
  List<td.Message> _videoMessages = [];
  bool _isLoading = true;
  int _lastMessageId = 0;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    final tdlib = context.read<TdlibService>();
    final logger = context.read<DebugLogService>();
    try {
      logger.info('Videos', 'Loading videos for chat ${widget.chat.title}');
      final result = await tdlib.getChatHistory(
        widget.chat.id,
        fromMessageId: _lastMessageId,
        limit: 50,
      );
      if (result is td.Messages) {
        final videos = result.messages
                ?.where((m) => m != null && m.content is td.MessageVideo)
                .cast<td.Message>()
                .toList() ??
            [];
        if (result.messages?.isNotEmpty == true) {
          _lastMessageId = result.messages!.last!.id;
        }
        setState(() {
          _videoMessages.addAll(videos);
          _isLoading = false;
        });
        logger.info('Videos', 'Loaded ${videos.length} video messages');
      }
    } catch (e) {
      logger.error('Videos', 'Failed to load videos: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.chat.title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _videoMessages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_off,
                          size: 64, color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('No videos found',
                          style: theme.textTheme.titleMedium),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _videoMessages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _videoMessages.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: FilledButton.tonal(
                          onPressed: _loadVideos,
                          child: const Text('Load More'),
                        ),
                      );
                    }
                    final msg = _videoMessages[index];
                    final video = (msg.content as td.MessageVideo).video;
                    final fileId = video.video.id;

                    return Selector<DownloadManager, DownloadTaskSnapshot?>(
                      selector: (_, manager) => manager.snapshotForFile(fileId),
                      builder: (context, task, _) {
                        return _VideoTile(
                          video: video,
                          message: msg,
                          task: task,
                          onDownload: () {
                            context.read<DownloadManager>().startDownload(
                              fileId: fileId,
                              chatId: widget.chat.id,
                              messageId: msg.id,
                              fileName: video.fileName.isNotEmpty
                                  ? video.fileName
                                  : 'video_${msg.id}.mp4',
                              totalBytes: video.video.expectedSize,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final td.Video video;
  final td.Message message;
  final DownloadTaskSnapshot? task;
  final VoidCallback onDownload;

  const _VideoTile({
    required this.video,
    required this.message,
    this.task,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = (video.video.expectedSize / 1024 / 1024).toStringAsFixed(1);
    final duration = Duration(seconds: video.duration);
    final durationStr =
        '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Thumbnail placeholder
            Container(
              width: 80,
              height: 60,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_fill,
                        color: theme.colorScheme.primary),
                    Text(durationStr, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.fileName.isNotEmpty
                        ? video.fileName
                        : 'Video ${message.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${video.width}x${video.height} · $size MB',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (task != null && !task!.isCompleted) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: task!.progress),
                    Text(task!.progressText,
                        style: theme.textTheme.labelSmall),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Action button
            if (task == null)
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: onDownload,
              )
            else if (task!.isCompleted)
              Icon(Icons.check_circle, color: theme.colorScheme.primary)
            else
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}
