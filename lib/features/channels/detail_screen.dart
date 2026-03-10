import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:handy_tdlib/api.dart' as td;
import 'package:tg_video_downloader/services/tdlib_service.dart';
import 'package:tg_video_downloader/services/download_manager.dart';
import 'package:tg_video_downloader/services/debug_log_service.dart';
import 'package:tg_video_downloader/features/channels/channels_screen.dart';

/// Screen for viewing and filtering different message types from a chat
class DetailScreen extends StatefulWidget {
  final td.Chat chat;

  const DetailScreen({
    super.key,
    required this.chat,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  MessageTypeFilter _filter = MessageTypeFilter.videos;
  List<td.Message> _messages = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _lastMessageId = 0;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final tdlib = context.read<TdlibService>();
    final logger = context.read<DebugLogService>();
    try {
      logger.info('Detail', 'Loading ${_filter.label} for chat ${widget.chat.title}');
      final result = await tdlib.getChatHistory(
        widget.chat.id,
        fromMessageId: _lastMessageId,
        limit: 50,
      );

      if (result is td.Messages) {
        final filteredMessages = result.messages
                ?.where((m) => m != null && _matchesFilter(m.content, _filter))
                .cast<td.Message>()
                .toList() ??
            [];

        if (result.messages?.isNotEmpty == true) {
          _lastMessageId = result.messages!.last!.id;
        }

        setState(() {
          _messages.addAll(filteredMessages);
          _isLoading = false;
          _hasMore = filteredMessages.length >= 20;
        });

        logger.info('Detail', 'Loaded ${filteredMessages.length} ${_filter.label} messages');
      }
    } catch (e) {
      logger.error('Detail', 'Failed to load messages: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Check if a message content matches the selected filter
  bool _matchesFilter(td.MessageContent? content, MessageTypeFilter filter) {
    if (content == null) return false;

    return switch (filter) {
      MessageTypeFilter.videos => content is td.MessageVideo,
      MessageTypeFilter.photos => content is td.MessagePhoto,
      MessageTypeFilter.documents => content is td.MessageDocument,
      MessageTypeFilter.audios => content is td.MessageAudio,
      MessageTypeFilter.animations => content is td.MessageAnimation,
      MessageTypeFilter.voiceNotes => content is td.MessageVoiceNote,
      MessageTypeFilter.stickers => content is td.MessageSticker,
      MessageTypeFilter.text => content is td.MessageText,
      MessageTypeFilter.all => true,
    };
  }

  void _onFilterChanged(MessageTypeFilter? newFilter) {
    if (newFilter != null && newFilter != _filter) {
      setState(() {
        _filter = newFilter;
        _messages.clear();
        _isLoading = true;
        _hasMore = true;
        _lastMessageId = 0;
      });
      _loadMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chat.title),
        actions: [
          PopupMenuButton<MessageTypeFilter>(
            icon: Icon(_filter.icon),
            tooltip: 'Filter messages',
            onSelected: _onFilterChanged,
            itemBuilder: (context) => MessageTypeFilter.values
                .map(
                  (filter) => PopupMenuItem(
                    value: filter,
                    child: Row(
                      children: [
                        Icon(filter.icon, size: 20),
                        const SizedBox(width: 12),
                        Text(filter.label),
                        if (_filter == filter) ...[
                          const Spacer(),
                          Icon(Icons.check, size: 20, color: theme.colorScheme.primary),
                        ],
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips row
          _buildFilterChips(theme),
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState(theme)
                    : _buildMessagesList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: MessageTypeFilter.values.length,
        itemBuilder: (context, index) {
          final filter = MessageTypeFilter.values[index];
          final isSelected = _filter == filter;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(filter.label),
              avatar: Icon(filter.icon, size: 18),
              selected: isSelected,
              onSelected: (_) => _onFilterChanged(filter),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              selectedColor: theme.colorScheme.primaryContainer,
              checkmarkColor: theme.colorScheme.onPrimaryContainer,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _filter.emptyIcon,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No ${_filter.label} found',
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(ThemeData theme) {
    return ListView.builder(
      itemCount: _messages.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.tonal(
              onPressed: _loadMessages,
              child: const Text('Load More'),
            ),
          );
        }

        final message = _messages[index];
        return _MessageDetailTile(
          message: message,
          chatId: widget.chat.id,
          messageType: _filter,
        );
      },
    );
  }
}

/// Enum representing different message content types for filtering
enum MessageTypeFilter {
  videos('Videos', Icons.videocam, Icons.videocam_off),
  photos('Photos', Icons.photo, Icons.photo_outlined),
  documents('Documents', Icons.insert_drive_file, Icons.description_outlined),
  audios('Audios', Icons.audio_file, Icons.audio_file_outlined),
  animations('GIFs', Icons.gif, Icons.gif_outlined),
  voiceNotes('Voice', Icons.mic, Icons.mic_none),
  stickers('Stickers', Icons.sentiment_satisfied, Icons.sentiment_satisfied_outlined),
  text('Text', Icons.text_fields, Icons.text_fields_outlined),
  all('All', Icons.apps, Icons.apps_outlined);

  final String label;
  final IconData icon;
  final IconData emptyIcon;

  const MessageTypeFilter(this.label, this.icon, this.emptyIcon);
}

/// Widget for displaying individual message details based on type
class _MessageDetailTile extends StatelessWidget {
  final td.Message message;
  final int chatId;
  final MessageTypeFilter messageType;

  const _MessageDetailTile({
    required this.message,
    required this.chatId,
    required this.messageType,
  });

  String _getFileId() {
    final content = message.content;
    return switch (content) {
      td.MessageVideo() => (content as td.MessageVideo).video.video.id,
      td.MessagePhoto() => (content as td.MessagePhoto).photo.id,
      td.MessageDocument() => (content as td.MessageDocument).document.document.id,
      td.MessageAudio() => (content as td.MessageAudio).audio.audio.id,
      td.MessageAnimation() => (content as td.MessageAnimation).animation.animation.id,
      td.MessageVoiceNote() => (content as td.MessageVoiceNote).voiceNote.voice.id,
      _ => '',
    };
  }

  String _getFileName() {
    final content = message.content;
    return switch (content) {
      td.MessageVideo(msg: final video) => video.video.fileName.isNotEmpty
          ? video.video.fileName
          : 'video_${message.id}.mp4',
      td.MessagePhoto() => 'photo_${message.id}.jpg',
      td.MessageDocument(msg: final doc) => doc.document.fileName.isNotEmpty
          ? doc.document.fileName
          : 'document_${message.id}',
      td.MessageAudio(msg: final audio) => audio.audio.fileName.isNotEmpty
          ? audio.audio.fileName
          : 'audio_${message.id}.mp3',
      td.MessageAnimation(msg: final gif) => gif.animation.fileName.isNotEmpty
          ? gif.animation.fileName
          : 'gif_${message.id}.mp4',
      td.MessageVoiceNote() => 'voice_${message.id}.ogg',
      td.MessageText() => 'text_${message.id}.txt',
      _ => 'message_${message.id}',
    };
  }

  int? getFileSize() {
    final content = message.content;
    return switch (content) {
      td.MessageVideo(msg: final video) => video.video.video.expectedSize,
      td.MessageDocument(msg: final doc) => doc.document.document.expectedSize,
      td.MessageAudio(msg: final audio) => audio.audio.audio.expectedSize,
      td.MessageAnimation(msg: final gif) => gif.animation.animation.expectedSize,
      td.MessageVoiceNote(msg: final voice) => voice.voiceNote.voice.expectedSize,
      _ => null,
    };
  }

  bool _isDownloadable() {
    return switch (messageType) {
      MessageTypeFilter.videos ||
      MessageTypeFilter.photos ||
      MessageTypeFilter.documents ||
      MessageTypeFilter.audios ||
      MessageTypeFilter.animations ||
      MessageTypeFilter.voiceNotes => true,
      MessageTypeFilter.stickers || MessageTypeFilter.text || MessageTypeFilter.all => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileId = _getFileId();

    return Selector<DownloadManager, DownloadTaskSnapshot?>(
      selector: (_, manager) => manager.snapshotForFile(fileId),
      builder: (context, task, _) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: _buildContent(context, theme, task),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    DownloadTaskSnapshot? task,
  ) {
    return switch (messageType) {
      MessageTypeFilter.videos => _buildVideoTile(theme, task),
      MessageTypeFilter.photos => _buildPhotoTile(theme, task),
      MessageTypeFilter.documents => _buildDocumentTile(theme, task),
      MessageTypeFilter.audios => _buildAudioTile(theme, task),
      MessageTypeFilter.animations => _buildAnimationTile(theme, task),
      MessageTypeFilter.voiceNotes => _buildVoiceNoteTile(theme, task),
      MessageTypeFilter.stickers => _buildStickerTile(theme),
      MessageTypeFilter.text => _buildTextTile(theme),
      MessageTypeFilter.all => _buildGenericTile(theme, task),
    };
  }

  Widget _buildVideoTile(ThemeData theme, DownloadTaskSnapshot? task) {
    final video = (message.content as td.MessageVideo).video;
    return _buildMediaTile(
      theme: theme,
      task: task,
      icon: Icons.play_circle_fill,
      title: video.fileName.isNotEmpty ? video.fileName : 'Video ${message.id}',
      subtitle: '${video.width}x${video.height} · ${_formatSize(video.video.expectedSize)}',
      duration: Duration(seconds: video.duration),
    );
  }

  Widget _buildPhotoTile(ThemeData theme, DownloadTaskSnapshot? task) {
    final photo = (message.content as td.MessagePhoto);
    return _buildMediaTile(
      theme: theme,
      task: task,
      icon: Icons.image,
      title: 'Photo ${message.id}',
      subtitle: 'Photo · ${photo.sizes.length} sizes',
    );
  }

  Widget _buildDocumentTile(ThemeData theme, DownloadTaskSnapshot? task) {
    final doc = (message.content as td.MessageDocument);
    return _buildMediaTile(
      theme: theme,
      task: task,
      icon: _getDocumentIcon(doc.document.mimeType),
      title: doc.document.fileName.isNotEmpty ? doc.document.fileName : 'Document ${message.id}',
      subtitle: _formatSize(doc.document.document.expectedSize),
    );
  }

  Widget _buildAudioTile(ThemeData theme, DownloadTaskSnapshot? task) {
    final audio = (message.content as td.MessageAudio).audio;
    final duration = Duration(seconds: audio.duration);
    return _buildMediaTile(
      theme: theme,
      task: task,
      icon: Icons.music_note,
      title: audio.fileName.isNotEmpty ? audio.fileName : 'Audio ${message.id}',
      subtitle: '${audio.performer ?? 'Unknown'} · ${audio.title ?? 'Unknown'} · ${_formatDuration(duration)}',
    );
  }

  Widget _buildAnimationTile(ThemeData theme, DownloadTaskSnapshot? task) {
    final animation = (message.content as td.MessageAnimation);
    return _buildMediaTile(
      theme: theme,
      task: task,
      icon: Icons.gif,
      title: animation.animation.fileName.isNotEmpty ? animation.animation.fileName : 'GIF ${message.id}',
      subtitle: '${animation.width}x${animation.height} · ${_formatSize(animation.animation.animation.expectedSize)}',
    );
  }

  Widget _buildVoiceNoteTile(ThemeData theme, DownloadTaskSnapshot? task) {
    final voice = (message.content as td.MessageVoiceNote).voiceNote;
    final duration = Duration(seconds: voice.duration);
    return _buildMediaTile(
      theme: theme,
      task: task,
      icon: Icons.mic,
      title: 'Voice Note ${message.id}',
      subtitle: _formatDuration(duration),
      isWaveform: voice.waveform.isNotEmpty,
    );
  }

  Widget _buildStickerTile(ThemeData theme) {
    final sticker = (message.content as td.MessageSticker);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(Icons.sentiment_satisfied, color: theme.colorScheme.onPrimaryContainer),
      ),
      title: Text(sticker.sticker.emoji),
      subtitle: Text('${sticker.sticker.setWidth}x${sticker.sticker.setHeight} · ${sticker.sticker.set.name}'),
      trailing: const Icon(Icons.emoji_emotions_outlined),
    );
  }

  Widget _buildTextTile(ThemeData theme) {
    final textMsg = (message.content as td.MessageText);
    final preview = textMsg.text.text.length > 50
        ? '${textMsg.text.text.substring(0, 50)}...'
        : textMsg.text.text;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.short_text),
      ),
      title: const Text('Text Message'),
      subtitle: Text(preview.isEmpty ? '(Empty message)' : preview),
      trailing: Text(
        _formatDate(message.date),
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  Widget _buildGenericTile(ThemeData theme, DownloadTaskSnapshot? task) {
    return _buildMediaTile(
      theme: theme,
      task: task,
      icon: Icons.insert_drive_file,
      title: 'Message ${message.id}',
      subtitle: message.content.runtimeType.toString(),
    );
  }

  Widget _buildMediaTile({
    required ThemeData theme,
    required DownloadTaskSnapshot? task,
    required IconData icon,
    required String title,
    required String subtitle,
    Duration? duration,
    bool isWaveform = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Icon/Thumbnail placeholder
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: duration != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: theme.colorScheme.primary, size: 28),
                        if (duration.inSeconds > 0)
                          Text(
                            _formatDuration(duration),
                            style: theme.textTheme.labelSmall,
                          ),
                      ],
                    )
                  : Icon(icon, color: theme.colorScheme.primary, size: 28),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall,
                ),
                if (task != null && !task.isCompleted) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: task.progress),
                  Text(task.progressText, style: theme.textTheme.labelSmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Action button
          if (_isDownloadable())
            _buildDownloadButton(context, theme, task),
        ],
      ),
    );
  }

  Widget _buildDownloadButton(
    BuildContext context,
    ThemeData theme,
    DownloadTaskSnapshot? task,
  ) {
    if (task == null) {
      return IconButton(
        icon: const Icon(Icons.download),
        onPressed: () => _startDownload(context),
      );
    } else if (task.isCompleted) {
      return Icon(Icons.check_circle, color: theme.colorScheme.primary);
    } else if (task.isFailed) {
      return IconButton(
        icon: const Icon(Icons.restart_alt),
        onPressed: () => _startDownload(context),
      );
    } else {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
  }

  void _startDownload(BuildContext context) {
    final fileId = _getFileId();
    context.read<DownloadManager>().startDownload(
          fileId: fileId,
          chatId: chatId,
          messageId: message.id,
          fileName: _getFileName(),
          totalBytes: getFileSize() ?? 0,
        );
  }

  IconData _getDocumentIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file;

    return switch (mimeType.split('/')[0]) {
      'image' => Icons.image,
      'video' => Icons.videocam,
      'audio' => Icons.audio_file,
      'text' => Icons.description,
      'application' => switch (mimeType) {
          'application/pdf' => Icons.picture_as_pdf,
          'application/zip' => Icons.archive,
          'application/json' => Icons.code,
          _ => Icons.insert_drive_file,
        },
      _ => Icons.insert_drive_file,
    };
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.day}/${date.month}/${date.year}';
  }
}
