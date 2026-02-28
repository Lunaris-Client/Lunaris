import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lunaris/core/models/chat_channel.dart';
import 'package:lunaris/core/providers/chat_provider.dart';
import 'package:lunaris/core/providers/message_bus_provider.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/ui/widgets/emoji_picker.dart';
import 'package:lunaris/core/services/frequent_emoji_service.dart';
import 'package:lunaris/core/utils/color_utils.dart';
import 'package:lunaris/app/router.dart';
import 'package:lunaris/features/topic/cooked_html_renderer.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

final bool _isDesktop = () {
  try {
    return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
  } catch (_) {
    return false;
  }
}();

class ChatChannelScreen extends ConsumerStatefulWidget {
  final String serverUrl;
  final ChatChannel channel;
  final int? targetMessageId;

  const ChatChannelScreen({
    super.key,
    required this.serverUrl,
    required this.channel,
    this.targetMessageId,
  });

  @override
  ConsumerState<ChatChannelScreen> createState() => _ChatChannelScreenState();
}

class _ChatChannelScreenState extends ConsumerState<ChatChannelScreen> {
  final _scrollController = ScrollController(keepScrollOffset: false);
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _unreadSeparatorKey = GlobalKey();
  final _targetMessageKey = GlobalKey();
  bool _sending = false;
  int? _replyToId;
  String? _replyToUsername;
  bool _showScrollToBottom = false;
  final List<int> _pendingUploadIds = [];
  late final int? _lastReadMessageId = widget.channel.lastReadMessageId;
  bool _needsScrollAfterRefresh = true;

  List<String> _typingUsers = [];
  Timer? _typingTimer;
  Timer? _presencePollTimer;
  bool _isTyping = false;
  final String _clientId = 'lunaris_${DateTime.now().millisecondsSinceEpoch}';

  late final _messageBusNotifier = ref.read(messageBusProvider.notifier);
  late final _authService = ref.read(authServiceProvider);
  late final _apiClient = ref.read(discourseApiClientProvider);
  late final _frequentEmojiService = ref.read(frequentEmojiServiceProvider);

  ChatMessagesParams get _params => ChatMessagesParams(
        serverUrl: widget.serverUrl,
        channelId: widget.channel.id,
      );

  String get _presenceChannel => '/chat-reply/${widget.channel.id}';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _textController.addListener(_onTextChanged);
    _presencePollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _pollTypingPresence(),
    );

    ref.listenManual<MessageBusEvent?>(messageBusProvider, (prev, next) {
      if (next == null || next.type != 'chat_channel_update') return;
      final data = next.data as Map<String, dynamic>;
      if (data['channel_id'] != widget.channel.id) return;
      ref
          .read(chatMessagesProvider(_params).notifier)
          .handleChatChannelMessage(data);
    });
    _messageBusNotifier.subscribeToChatChannel(widget.channel.id);

    debugPrint('[ChatScroll] initState: channelId=${widget.channel.id} lastReadMessageId=$_lastReadMessageId needsScroll=$_needsScrollAfterRefresh keepScrollOffset=${_scrollController.keepScrollOffset}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(chatMessagesProvider(_params).notifier).refresh();
    });
  }

  @override
  void deactivate() {
    _markMessagesAsRead();
    super.deactivate();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _presencePollTimer?.cancel();
    _messageBusNotifier.unsubscribeFromChatChannel(widget.channel.id);
    _scrollController.dispose();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    _leavePresence();
    super.dispose();
  }

  void _markMessagesAsRead() {
    final messagesNotifier = ref.read(chatMessagesProvider(_params).notifier);
    final channelListNotifier =
        ref.read(chatChannelListProvider(widget.serverUrl).notifier);
    Future.microtask(() {
      messagesNotifier.markAllRead();
      channelListNotifier.markChannelAsRead(widget.channel.id);
    });
  }

  void _onTextChanged() {
    if (_textController.text.trim().isNotEmpty && !_isTyping) {
      _isTyping = true;
      _joinPresence();
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 4), () {
      _isTyping = false;
      _leavePresence();
    });
  }

  Future<void> _joinPresence() async {
    try {
      final apiKey =
          await _authService.loadApiKey(widget.serverUrl);
      if (apiKey == null) return;
      await _apiClient.updatePresence(
            widget.serverUrl,
            apiKey,
            clientId: _clientId,
            presentChannels: [_presenceChannel],
          );
    } catch (_) {}
  }

  Future<void> _leavePresence() async {
    try {
      final apiKey =
          await _authService.loadApiKey(widget.serverUrl);
      if (apiKey == null) return;
      await _apiClient.updatePresence(
            widget.serverUrl,
            apiKey,
            clientId: _clientId,
            leaveChannels: [_presenceChannel],
          );
    } catch (_) {}
  }

  Future<void> _pollTypingPresence() async {
    if (!mounted) return;
    try {
      final apiKey =
          await _authService.loadApiKey(widget.serverUrl);
      if (apiKey == null || !mounted) return;
      final account = ref.read(activeServerProvider);
      final data = await _apiClient.getPresence(
            widget.serverUrl,
            apiKey,
            channels: [_presenceChannel],
          );
      if (!mounted) return;
      final channelData = data[_presenceChannel] as Map<String, dynamic>?;
      final users = channelData?['users'] as List<dynamic>? ?? [];
      final names = users
          .map((u) => (u as Map<String, dynamic>)['username'] as String?)
          .where((name) => name != null && name != account?.username)
          .cast<String>()
          .toList();
      if (mounted) {
        setState(() => _typingUsers = names);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _typingUsers = []);
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatMessagesProvider(_params).notifier).loadMore();
    }

    final atBottom = _scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 100;
    if (_showScrollToBottom == atBottom) {
      setState(() => _showScrollToBottom = !atBottom);
    }
  }

  void _scrollToBottom() {
    debugPrint('[ChatScroll] _scrollToBottom called');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        debugPrint('[ChatScroll] _scrollToBottom: mounted=$mounted hasClients=${_scrollController.hasClients}');
        return;
      }
      debugPrint('[ChatScroll] _scrollToBottom: pixels=${_scrollController.position.pixels} min=${_scrollController.position.minScrollExtent} max=${_scrollController.position.maxScrollExtent} -> animating to 0');
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _scrollToUnread() {
    debugPrint('[ChatScroll] _scrollToUnread called');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _unreadSeparatorKey.currentContext;
      debugPrint('[ChatScroll] _scrollToUnread: separatorContext=${ctx != null}');
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.85,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToTargetMessage() {
    debugPrint('[ChatScroll] _scrollToTargetMessage called for id=${widget.targetMessageId}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _targetMessageKey.currentContext;
      debugPrint('[ChatScroll] _scrollToTargetMessage: targetContext=${ctx != null}');
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _isTyping = false;
    });
    _typingTimer?.cancel();
    _leavePresence();
    _textController.clear();

    final account = ref.read(activeServerProvider);

    await ref.read(chatMessagesProvider(_params).notifier).sendMessage(
          text,
          inReplyToId: _replyToId,
          username: account?.username,
          avatarTemplate: account?.avatarTemplate,
          userId: account?.userId,
          uploadIds: _pendingUploadIds.isNotEmpty
              ? List<int>.from(_pendingUploadIds)
              : null,
        );

    if (mounted) {
      setState(() {
        _sending = false;
        _replyToId = null;
        _replyToUsername = null;
        _pendingUploadIds.clear();
      });
      _scrollToBottom();
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    try {
      final apiKey =
          await _authService.loadApiKey(widget.serverUrl);
      if (apiKey == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading image…')),
        );
      }

      final result = await _apiClient.uploadFile(
            widget.serverUrl,
            apiKey,
            filePath: picked.path,
            fileName: picked.name,
          );

      final shortUrl = result['short_url'] as String?;
      final url = result['url'] as String?;
      final uploadId = result['id'] as int?;
      final imageUrl = shortUrl ?? url;

      if (imageUrl != null && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (uploadId != null) _pendingUploadIds.add(uploadId);
        final text = _textController.text;
        final imageMarkdown = '![${picked.name}]($imageUrl)';
        _textController.text =
            text.isEmpty ? imageMarkdown : '$text\n$imageMarkdown';
        _textController.selection = TextSelection.collapsed(
          offset: _textController.text.length,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  void _setReply(ChatMessage msg) {
    setState(() {
      _replyToId = msg.id;
      _replyToUsername = msg.username;
    });
    _focusNode.requestFocus();
  }

  void _clearReply() {
    setState(() {
      _replyToId = null;
      _replyToUsername = null;
    });
  }

  void _openThread(ChatMessage msg) {
    if (msg.threadId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          serverUrl: widget.serverUrl,
          channelId: widget.channel.id,
          threadId: msg.threadId!,
        ),
      ),
    );
  }

  Future<void> _editMessage(ChatMessage msg) async {
    final controller = TextEditingController(text: msg.message);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 8,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty && result != msg.message) {
      ref.read(chatMessagesProvider(_params).notifier).editMessage(msg.id, result);
    }
  }

  Future<void> _deleteMessage(ChatMessage msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(chatMessagesProvider(_params).notifier).deleteMessage(msg.id);
    }
  }

  Future<void> _bookmarkMessage(ChatMessage msg) async {
    try {
      final apiKey =
          await _authService.loadApiKey(widget.serverUrl);
      if (apiKey == null) return;
      await _apiClient.bookmarkChatMessage(
            widget.serverUrl,
            apiKey,
            messageId: msg.id,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message bookmarked')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to bookmark: $e')),
        );
      }
    }
  }

  void _copyMessageLink(ChatMessage msg) {
    final url =
        '${widget.serverUrl}/chat/c/-/${widget.channel.id}/${msg.id}';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
  }

  void _selectMessageText(ChatMessage msg) {
    Clipboard.setData(ClipboardData(text: msg.message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Text copied to clipboard')),
    );
  }

  Future<void> _flagMessage(ChatMessage msg) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Flag message'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, '3'),
            child: const Text('Off-Topic'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, '4'),
            child: const Text('Inappropriate'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, '8'),
            child: const Text('Spam'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, '7'),
            child: const Text('Something else'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    try {
      final apiKey =
          await _authService.loadApiKey(widget.serverUrl);
      if (apiKey == null || !mounted) return;
      await _apiClient.flagChatMessage(
            widget.serverUrl,
            apiKey,
            widget.channel.id,
            msg.id,
            flagType: int.parse(reason),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message flagged')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to flag: $e')),
        );
      }
    }
  }

  Future<void> _reactToMessage(ChatMessage msg, [Offset? position]) async {
    final emoji = await showEmojiPickerDialog(
      context: context,
      serverUrl: widget.serverUrl,
      anchorPosition: position,
    );
    if (emoji == null) return;
    HapticFeedback.mediumImpact();
    _frequentEmojiService.recordUsage(emoji);
    try {
      final apiKey =
          await _authService.loadApiKey(widget.serverUrl);
      if (apiKey == null || !mounted) return;
      await _apiClient.reactChatMessage(
            widget.serverUrl,
            apiKey,
            widget.channel.id,
            msg.id,
            emoji: emoji,
            action: 'add',
          );
      if (!mounted) return;
      ref.read(chatMessagesProvider(_params).notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to react: $e')),
        );
      }
    }
  }

  Future<void> _toggleReaction(ChatMessage msg, String emoji, bool alreadyReacted) async {
    HapticFeedback.mediumImpact();
    if (!alreadyReacted) _frequentEmojiService.recordUsage(emoji);
    try {
      final apiKey =
          await _authService.loadApiKey(widget.serverUrl);
      if (apiKey == null || !mounted) return;
      await _apiClient.reactChatMessage(
            widget.serverUrl,
            apiKey,
            widget.channel.id,
            msg.id,
            emoji: emoji,
            action: alreadyReacted ? 'remove' : 'add',
          );
      if (!mounted) return;
      ref.read(chatMessagesProvider(_params).notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to react: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatMessagesProvider(_params));
    final theme = Theme.of(context);

    ref.listen(chatMessagesProvider(_params), (prev, next) {
      debugPrint('[ChatScroll] listen: isLoading=${next.isLoading} msgCount=${next.messages.length} prevMsgCount=${prev?.messages.length} needsScroll=$_needsScrollAfterRefresh showScrollToBottom=$_showScrollToBottom');
      if (_needsScrollAfterRefresh &&
          !next.isLoading &&
          next.messages.isNotEmpty) {
        _needsScrollAfterRefresh = false;
        final lastRead = _lastReadMessageId;
        final hasUnread = lastRead != null &&
            next.messages.any((m) => m.id > lastRead);
        debugPrint('[ChatScroll] initial load done: lastRead=$lastRead hasUnread=$hasUnread msgIds=[${next.messages.first.id}..${next.messages.last.id}]');
        if (widget.targetMessageId != null &&
            next.messages.any((m) => m.id == widget.targetMessageId)) {
          _scrollToTargetMessage();
        } else if (hasUnread) {
          _scrollToUnread();
        }
        return;
      }
      if (prev != null &&
          next.messages.length > prev.messages.length &&
          !_showScrollToBottom) {
        debugPrint('[ChatScroll] new messages arrived, scrolling to bottom');
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              widget.channel.isDirectMessage
                  ? Icons.person_rounded
                  : Icons.tag_rounded,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.channel.title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.read(chatMessagesProvider(_params).notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _buildMessageList(state, theme),
                if (_showScrollToBottom)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.small(
                      onPressed: _scrollToBottom,
                      child: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ),
              ],
            ),
          ),
          if (_replyToId != null)
            _ReplyBanner(
              username: _replyToUsername ?? 'someone',
              onClear: _clearReply,
            ),
          if (_typingUsers.isNotEmpty)
            _TypingIndicator(usernames: _typingUsers),
          _ChatComposer(
            controller: _textController,
            focusNode: _focusNode,
            sending: _sending,
            onSend: _send,
            serverUrl: widget.serverUrl,
            onInsertEmoji: () async {
              final emoji = await showEmojiPickerDialog(
                context: context,
                serverUrl: widget.serverUrl,
              );
              if (emoji == null) return;
              final emojiText = ':$emoji: ';
              final text = _textController.text;
              final selection = _textController.selection;
              final pos = selection.start == -1 ? text.length : selection.start;
              final end = selection.end == -1 ? text.length : selection.end;
              final newText = text.replaceRange(pos, end, emojiText);
              _textController.text = newText;
              _textController.selection = TextSelection.collapsed(
                offset: pos + emojiText.length,
              );
            },
            onAttachImage: _pickAndUploadImage,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatMessagesState state, ThemeData theme) {
    if (state.isLoading && state.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48,
                  color: theme.colorScheme.error.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              Text('Failed to load messages',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(chatMessagesProvider(_params).notifier).refresh(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    debugPrint('[ChatScroll] buildMessageList: msgCount=${state.messages.length} isLoading=${state.isLoading} isLoadingMore=${state.isLoadingMore} scrollHasClients=${_scrollController.hasClients} scrollPixels=${_scrollController.hasClients ? _scrollController.position.pixels : "N/A"}');
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: state.messages.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (state.isLoadingMore && index == state.messages.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final msgIndex = state.messages.length - 1 - index;
        final msg = state.messages[msgIndex];
        final prevMsg = msgIndex > 0 ? state.messages[msgIndex - 1] : null;
        final isReply = msg.inReplyToId != null;
        final showHeader = isReply ||
            prevMsg == null ||
            prevMsg.username != msg.username ||
            msg.createdAt.difference(prevMsg.createdAt).inMinutes > 5;

        final showDateSeparator = prevMsg == null ||
            !_isSameDay(prevMsg.createdAt, msg.createdAt);

        final lastRead = _lastReadMessageId;
        final showUnreadSeparator = lastRead != null &&
            prevMsg != null &&
            prevMsg.id <= lastRead &&
            msg.id > lastRead;

        String? replyToUsername;
        String? replyToExcerpt;
        String? replyToAvatarTemplate;
        if (msg.inReplyToId != null) {
          // Prefer data parsed from the API's in_reply_to object
          replyToUsername = msg.replyToUsername;
          replyToExcerpt = msg.replyToExcerpt;
          replyToAvatarTemplate = msg.replyToAvatarTemplate;
          // Fall back to lookup in loaded messages
          if (replyToUsername == null) {
            final replyTarget = state.messages
                .where((m) => m.id == msg.inReplyToId)
                .firstOrNull;
            if (replyTarget != null) {
              replyToUsername = replyTarget.username;
              replyToExcerpt = replyTarget.excerpt ?? replyTarget.message;
              replyToAvatarTemplate = replyTarget.avatarTemplate;
            }
          }
          // Last resort: show generic indicator
          replyToUsername ??= 'someone';
        }

        final account = ref.read(activeServerProvider);
        final isOwnMessage = msg.userId != null &&
            account?.userId != null &&
            msg.userId == account!.userId;

        final frequentEmojis = _frequentEmojiService.getTopEmojis(6);

        final isTarget = widget.targetMessageId != null && msg.id == widget.targetMessageId;

        return Column(
          key: isTarget ? _targetMessageKey : null,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDateSeparator)
              _DateSeparator(date: msg.createdAt),
            if (showUnreadSeparator)
              _UnreadSeparator(key: _unreadSeparatorKey),
            _ChatMessageBubble(
              message: msg,
              serverUrl: widget.serverUrl,
              showHeader: showHeader,
              isOwnMessage: isOwnMessage,
              replyToUsername: replyToUsername,
              replyToExcerpt: replyToExcerpt,
              replyToAvatarTemplate: replyToAvatarTemplate,
              frequentEmojis: frequentEmojis,
              onReply: () => _setReply(msg),
              onThreadTap: msg.threadId != null ? () => _openThread(msg) : null,
              onEdit: isOwnMessage ? () => _editMessage(msg) : null,
              onDelete: isOwnMessage ? () => _deleteMessage(msg) : null,
              onBookmark: () => _bookmarkMessage(msg),
              onCopyLink: () => _copyMessageLink(msg),
              onSelect: () => _selectMessageText(msg),
              onFlag: !isOwnMessage ? () => _flagMessage(msg) : null,
              onReact: (position) => _reactToMessage(msg, position),
              onReactionTap: (emoji, reacted) => _toggleReaction(msg, emoji, reacted),
              onUserTap: (username) => context.push(
                '/user/$username',
                extra: UserProfileRouteExtra(serverUrl: widget.serverUrl),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChatMessageBubble extends StatefulWidget {
  final ChatMessage message;
  final String serverUrl;
  final bool showHeader;
  final bool isOwnMessage;
  final String? replyToUsername;
  final String? replyToExcerpt;
  final String? replyToAvatarTemplate;
  final VoidCallback? onReply;
  final VoidCallback? onThreadTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onBookmark;
  final VoidCallback? onCopyLink;
  final VoidCallback? onSelect;
  final VoidCallback? onFlag;
  final void Function(Offset? position)? onReact;
  final void Function(String emoji, bool alreadyReacted)? onReactionTap;
  final List<String> frequentEmojis;
  final ValueChanged<String>? onUserTap;

  const _ChatMessageBubble({
    required this.message,
    required this.serverUrl,
    required this.showHeader,
    this.isOwnMessage = false,
    this.replyToUsername,
    this.replyToExcerpt,
    this.replyToAvatarTemplate,
    this.frequentEmojis = const [],
    this.onReply,
    this.onThreadTap,
    this.onEdit,
    this.onDelete,
    this.onBookmark,
    this.onCopyLink,
    this.onSelect,
    this.onFlag,
    this.onReact,
    this.onReactionTap,
    this.onUserTap,
  });

  @override
  State<_ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<_ChatMessageBubble> {
  double _swipeOffset = 0;
  bool _isHovered = false;

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _swipeOffset = (_swipeOffset + details.delta.dx).clamp(-60.0, 0.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_swipeOffset < -40) {
      widget.onReply?.call();
    }
    setState(() => _swipeOffset = 0);
  }

  void _showContextMenu(BuildContext context, [Offset? position]) {
    final items = <PopupMenuEntry<String>>[];

    items.add(const PopupMenuItem(value: 'react', child: ListTile(
      leading: Icon(Icons.add_reaction_outlined), title: Text('React'),
      dense: true, contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    )));
    final quickEmojis = widget.frequentEmojis;
    items.insert(0, PopupMenuItem<String>(
      enabled: false,
      height: 44,
      child: _QuickReactionBar(
        serverUrl: widget.serverUrl,
        emojis: quickEmojis,
        onSelected: (emoji) {
          Navigator.pop(context, emoji);
        },
      ),
    ));
    items.add(const PopupMenuItem(value: 'reply', child: ListTile(
      leading: Icon(Icons.reply_rounded), title: Text('Reply'), dense: true,
      contentPadding: EdgeInsets.zero, visualDensity: VisualDensity.compact,
    )));
    if (widget.onEdit != null) {
      items.add(const PopupMenuItem(value: 'edit', child: ListTile(
        leading: Icon(Icons.edit_rounded), title: Text('Edit'), dense: true,
        contentPadding: EdgeInsets.zero, visualDensity: VisualDensity.compact,
      )));
    }
    items.add(const PopupMenuItem(value: 'bookmark', child: ListTile(
      leading: Icon(Icons.bookmark_add_outlined), title: Text('Bookmark'),
      dense: true, contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    )));
    items.add(const PopupMenuItem(value: 'copy_link', child: ListTile(
      leading: Icon(Icons.link_rounded), title: Text('Copy link'), dense: true,
      contentPadding: EdgeInsets.zero, visualDensity: VisualDensity.compact,
    )));
    items.add(const PopupMenuItem(value: 'select', child: ListTile(
      leading: Icon(Icons.content_copy_rounded), title: Text('Copy text'),
      dense: true, contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    )));
    if (widget.onFlag != null) {
      items.add(const PopupMenuDivider());
      items.add(const PopupMenuItem(value: 'flag', child: ListTile(
        leading: Icon(Icons.flag_outlined, color: Colors.orange),
        title: Text('Flag'), dense: true, contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      )));
    }
    if (widget.onDelete != null) {
      if (widget.onFlag == null) items.add(const PopupMenuDivider());
      items.add(const PopupMenuItem(value: 'delete', child: ListTile(
        leading: Icon(Icons.delete_outline_rounded, color: Colors.red),
        title: Text('Delete', style: TextStyle(color: Colors.red)),
        dense: true, contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      )));
    }

    final renderBox = context.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final pos = position ??
        renderBox.localToGlobal(
          Offset(renderBox.size.width / 2, renderBox.size.height / 2),
          ancestor: overlay,
        );

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        pos.dx,
        pos.dy,
        overlay.size.width - pos.dx,
        overlay.size.height - pos.dy,
      ),
      items: items,
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'react':
          widget.onReact?.call(null);
        case 'reply':
          widget.onReply?.call();
        case 'edit':
          widget.onEdit?.call();
        case 'bookmark':
          widget.onBookmark?.call();
        case 'copy_link':
          widget.onCopyLink?.call();
        case 'select':
          widget.onSelect?.call();
        case 'flag':
          widget.onFlag?.call();
        case 'delete':
          widget.onDelete?.call();
        default:
          // Quick reaction shortcode from _QuickReactionBar
          if (value.isNotEmpty) {
            HapticFeedback.mediumImpact();
            widget.onReactionTap?.call(value, false);
          }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final msg = widget.message;

    if (msg.deleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 44),
        child: Text(
          '[message deleted]',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final hasReplyContext = widget.replyToUsername != null;

    Widget content = Padding(
      padding: EdgeInsets.only(
        top: widget.showHeader ? 10 : 1,
        bottom: 1,
        left: 4,
        right: 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeader)
            GestureDetector(
              onTap: () {
                final username = widget.message.username;
                if (username != null) widget.onUserTap?.call(username);
              },
              child: _buildAvatar(theme),
            )
          else
            const SizedBox(width: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showHeader)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            final username = widget.message.username;
                            if (username != null) widget.onUserTap?.call(username);
                          },
                          child: Text(
                            msg.username ?? 'Unknown',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timeago.format(msg.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (hasReplyContext)
                  _InlineReplyIndicator(
                    username: widget.replyToUsername!,
                    excerpt: widget.replyToExcerpt,
                    avatarTemplate: widget.replyToAvatarTemplate,
                    serverUrl: widget.serverUrl,
                  ),
                if (msg.cooked != null && msg.cooked!.isNotEmpty)
                  CookedHtmlRenderer(
                    html: msg.cooked!,
                    serverUrl: widget.serverUrl,
                    onMentionTap: (username) => widget.onUserTap?.call(username),
                  )
                else
                  _EmojiRichText(
                    text: msg.message,
                    serverUrl: widget.serverUrl,
                    style: theme.textTheme.bodyMedium,
                  ),
                if (msg.reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: msg.reactions.map((r) {
                        final userNames = r.users.map((u) => u.username).toList();
                        final tooltipText = userNames.isNotEmpty
                            ? userNames.join(', ')
                            : '${r.count} reaction${r.count != 1 ? 's' : ''}';
                        return Tooltip(
                          message: tooltipText,
                          preferBelow: false,
                          waitDuration: const Duration(milliseconds: 300),
                          child: GestureDetector(
                            onTap: () => widget.onReactionTap?.call(r.emoji, r.reacted),
                            onLongPress: () {
                              HapticFeedback.mediumImpact();
                              showDialog(
                                context: context,
                                builder: (_) => _ReactionUsersDialog(
                                  emoji: r.emoji,
                                  users: userNames,
                                  serverUrl: widget.serverUrl,
                                  count: r.count,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: r.reacted
                                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                                border: r.reacted
                                    ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4))
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.network(
                                    '${widget.serverUrl}/images/emoji/twitter/${r.emoji}.png',
                                    width: 14,
                                    height: 14,
                                    errorBuilder: (_, __, ___) =>
                                        Text(r.emoji, style: const TextStyle(fontSize: 12)),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${r.count}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: r.reacted ? FontWeight.w600 : null,
                                      color: r.reacted
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                if (widget.onThreadTap != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: InkWell(
                      onTap: widget.onThreadTap,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 2, horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.forum_outlined, size: 14,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              'View thread',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (_isDesktop) {
      content = MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onSecondaryTapUp: (details) =>
              _showContextMenu(context, details.globalPosition),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _isHovered
                      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                      : null,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: content,
              ),
              if (_isHovered)
                Positioned(
                  top: 0,
                  right: 4,
                  child: _HoverActions(
                    serverUrl: widget.serverUrl,
                    onReply: widget.onReply,
                    onReact: (btnContext) {
                      final box = btnContext.findRenderObject() as RenderBox;
                      final pos = box.localToGlobal(Offset(0, box.size.height));
                      widget.onReact?.call(pos);
                    },
                    onQuickReact: (emoji) => widget.onReactionTap?.call(emoji, false),
                    onEdit: widget.onEdit,
                    onBookmark: widget.onBookmark,
                    onMore: () => _showContextMenu(context),
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      content = GestureDetector(
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _showContextMenu(context);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (_swipeOffset < -10)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.reply_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(_swipeOffset, 0),
              child: content,
            ),
          ],
        ),
      );
    }

    return content;
  }

  Widget _buildAvatar(ThemeData theme) {
    if (widget.message.avatarTemplate != null) {
      final url = resolveAvatarUrl(
          widget.serverUrl, widget.message.avatarTemplate!, size: 40);
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(url),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Text(
        (widget.message.username ?? '?')[0].toUpperCase(),
        style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    String label;
    if (_isSameDay(date, now)) {
      label = 'Today';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      label = DateFormat.EEEE().format(date);
    } else {
      label = DateFormat.yMMMd().format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(child: Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}

class _UnreadSeparator extends StatelessWidget {
  const _UnreadSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: theme.colorScheme.error, thickness: 1.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'New',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: theme.colorScheme.error, thickness: 1.5)),
        ],
      ),
    );
  }
}

class _InlineReplyIndicator extends StatelessWidget {
  final String username;
  final String? excerpt;
  final String? avatarTemplate;
  final String serverUrl;

  const _InlineReplyIndicator({
    required this.username,
    required this.serverUrl,
    this.excerpt,
    this.avatarTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Strip HTML tags from excerpt for clean display
    String? cleanExcerpt = excerpt;
    if (cleanExcerpt != null) {
      cleanExcerpt = cleanExcerpt.replaceAll(RegExp(r'<[^>]*>'), '');
      if (cleanExcerpt.length > 80) {
        cleanExcerpt = '${cleanExcerpt.substring(0, 80)}…';
      }
    }

    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.15);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shortcut_rounded,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 6),
            if (avatarTemplate != null)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: CircleAvatar(
                  radius: 8,
                  backgroundImage: NetworkImage(
                    resolveAvatarUrl(serverUrl, avatarTemplate!, size: 20),
                  ),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            Text(
              username,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (cleanExcerpt != null && cleanExcerpt.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(
                  '·',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    fontSize: 12,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  cleanExcerpt,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HoverActions extends ConsumerWidget {
  final String serverUrl;
  final VoidCallback? onReply;
  final void Function(BuildContext context)? onReact;
  final void Function(String emoji)? onQuickReact;
  final VoidCallback? onEdit;
  final VoidCallback? onBookmark;
  final VoidCallback? onMore;

  const _HoverActions({
    required this.serverUrl,
    this.onReply,
    this.onReact,
    this.onQuickReact,
    this.onEdit,
    this.onBookmark,
    this.onMore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final quickEmojis = ref.read(frequentEmojiServiceProvider).getTopEmojis(3);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...quickEmojis.map((emoji) => _emojiBtn(emoji)),
          if (onReact != null)
            Builder(
              builder: (btnContext) => _hoverBtn(
                Icons.add_reaction_outlined,
                'React',
                () => onReact!(btnContext),
              ),
            ),
          if (onReply != null)
            _hoverBtn(Icons.reply_rounded, 'Reply', onReply!),
          if (onEdit != null)
            _hoverBtn(Icons.edit_rounded, 'Edit', onEdit!),
          if (onBookmark != null)
            _hoverBtn(Icons.bookmark_add_outlined, 'Bookmark', onBookmark!),
          if (onMore != null)
            _hoverBtn(Icons.more_horiz_rounded, 'More', onMore!),
        ],
      ),
    );
  }

  Widget _emojiBtn(String shortcode) {
    return Tooltip(
      message: ':$shortcode:',
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => onQuickReact?.call(shortcode),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Image.network(
            '$serverUrl/images/emoji/twitter/$shortcode.png',
            width: 18,
            height: 18,
          ),
        ),
      ),
    );
  }

  Widget _hoverBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        icon: Icon(icon, size: 14),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        tooltip: tooltip,
      ),
    );
  }
}

class _ReplyBanner extends StatelessWidget {
  final String username;
  final VoidCallback onClear;

  const _ReplyBanner({required this.username, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, size: 16,
              color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Replying to $username',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: onClear,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback? onInsertEmoji;
  final VoidCallback? onAttachImage;
  final String serverUrl;

  const _ChatComposer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
    required this.serverUrl,
    this.onInsertEmoji,
    this.onAttachImage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        4,
        8,
        8,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onInsertEmoji != null)
            IconButton(
              onPressed: onInsertEmoji,
              icon: Icon(
                Icons.emoji_emotions_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: 'Emoji',
            ),
          if (onAttachImage != null)
            IconButton(
              onPressed: onAttachImage,
              icon: Icon(
                Icons.image_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: 'Image / GIF',
            ),
          Expanded(
            child: Focus(
              onKeyEvent: _isDesktop
                  ? (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        if (!sending) onSend();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    }
                  : null,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 5,
                textInputAction:
                    _isDesktop ? TextInputAction.none : TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  final List<String> usernames;

  const _TypingIndicator({required this.usernames});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String text;
    if (usernames.length == 1) {
      text = '${usernames[0]} is typing';
    } else if (usernames.length == 2) {
      text = '${usernames[0]} and ${usernames[1]} are typing';
    } else if (usernames.length <= 3) {
      text = '${usernames.sublist(0, usernames.length - 1).join(', ')} '
          'and ${usernames.last} are typing';
    } else {
      text = '${usernames[0]}, ${usernames[1]} and '
          '${usernames.length - 2} others are typing';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 12,
            child: _TypingDots(),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final opacity =
                ((_controller.value + delay) % 1.0 < 0.5) ? 1.0 : 0.3;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Opacity(
                opacity: opacity,
                child: CircleAvatar(
                  radius: 3,
                  backgroundColor: color,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _QuickReactionBar extends StatelessWidget {
  final String serverUrl;
  final List<String> emojis;
  final ValueChanged<String> onSelected;

  const _QuickReactionBar({
    required this.serverUrl,
    required this.emojis,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: emojis.map((shortcode) {
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onSelected(shortcode),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Image.network(
              '$serverUrl/images/emoji/twitter/$shortcode.png',
              width: 24,
              height: 24,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class ChatThreadScreen extends ConsumerStatefulWidget {
  final String serverUrl;
  final int channelId;
  final int threadId;

  const ChatThreadScreen({
    super.key,
    required this.serverUrl,
    required this.channelId,
    required this.threadId,
  });

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _sending = false;

  ThreadMessagesParams get _params => ThreadMessagesParams(
        serverUrl: widget.serverUrl,
        channelId: widget.channelId,
        threadId: widget.threadId,
      );

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _textController.clear();

    final account = ref.read(activeServerProvider);

    await ref.read(threadMessagesProvider(_params).notifier).sendMessage(
          text,
          username: account?.username,
          avatarTemplate: account?.avatarTemplate,
          userId: account?.userId,
        );

    if (mounted) {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(threadMessagesProvider(_params));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Thread')),
      body: Column(
        children: [
          Expanded(child: _buildMessages(state, theme)),
          _ChatComposer(
            controller: _textController,
            focusNode: _focusNode,
            sending: _sending,
            onSend: _send,
            serverUrl: widget.serverUrl,
          ),
        ],
      ),
    );
  }

  Widget _buildMessages(ChatMessagesState state, ThemeData theme) {
    if (state.isLoading && state.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.messages.isEmpty) {
      return Center(
        child: Text(
          'No replies yet',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final msg = state.messages[index];
        final prevMsg = index > 0 ? state.messages[index - 1] : null;
        final isReply = msg.inReplyToId != null;
        final showHeader = isReply ||
            prevMsg == null ||
            prevMsg.username != msg.username ||
            msg.createdAt.difference(prevMsg.createdAt).inMinutes > 5;

        final showDateSeparator = prevMsg == null ||
            !_isSameDay(prevMsg.createdAt, msg.createdAt);

        String? replyToUsername;
        String? replyToExcerpt;
        String? replyToAvatarTemplate;
        if (msg.inReplyToId != null) {
          replyToUsername = msg.replyToUsername;
          replyToExcerpt = msg.replyToExcerpt;
          replyToAvatarTemplate = msg.replyToAvatarTemplate;
          if (replyToUsername == null) {
            final replyTarget = state.messages
                .where((m) => m.id == msg.inReplyToId)
                .firstOrNull;
            if (replyTarget != null) {
              replyToUsername = replyTarget.username;
              replyToExcerpt = replyTarget.excerpt ?? replyTarget.message;
              replyToAvatarTemplate = replyTarget.avatarTemplate;
            }
          }
          replyToUsername ??= 'someone';
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDateSeparator)
              _DateSeparator(date: msg.createdAt),
            _ChatMessageBubble(
              message: msg,
              serverUrl: widget.serverUrl,
              showHeader: showHeader,
              replyToUsername: replyToUsername,
              replyToExcerpt: replyToExcerpt,
              replyToAvatarTemplate: replyToAvatarTemplate,
              onUserTap: (username) => context.push(
                '/user/$username',
                extra: UserProfileRouteExtra(serverUrl: widget.serverUrl),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReactionUsersDialog extends StatelessWidget {
  final String emoji;
  final List<String> users;
  final String serverUrl;
  final int count;

  const _ReactionUsersDialog({
    required this.emoji,
    required this.users,
    required this.serverUrl,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      title: Row(
        children: [
          Image.network(
            '$serverUrl/images/emoji/twitter/$emoji.png',
            width: 24,
            height: 24,
            errorBuilder: (_, __, ___) =>
                Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 8),
          Text(
            users.isNotEmpty ? '${users.length}' : '$count',
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
      content: users.isNotEmpty
          ? ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300, maxWidth: 280),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: users.map((username) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, size: 18,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text(username, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            )
          : Text(
              '$count reaction${count != 1 ? 's' : ''}',
              style: theme.textTheme.bodyMedium,
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

final _emojiShortcodePattern = RegExp(r':([a-zA-Z0-9_+\-]+):');

class _EmojiRichText extends StatelessWidget {
  final String text;
  final String serverUrl;
  final TextStyle? style;

  const _EmojiRichText({
    required this.text,
    required this.serverUrl,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final matches = _emojiShortcodePattern.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: style);
    }

    final spans = <InlineSpan>[];
    var lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      final shortcode = match.group(1)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Image.network(
            '$serverUrl/images/emoji/twitter/$shortcode.png',
            width: 20,
            height: 20,
            errorBuilder: (_, __, ___) =>
                Text(':$shortcode:', style: style),
          ),
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return Text.rich(TextSpan(children: spans, style: style));
  }
}
