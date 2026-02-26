import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/providers/draft_provider.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/core/providers/topic_detail_provider.dart';
import 'package:lunaris/features/composer/markdown_toolbar.dart';

class ReplyComposerScreen extends ConsumerStatefulWidget {
  final String serverUrl;
  final int topicId;
  final String topicTitle;
  final int? replyToPostNumber;
  final String? replyToUsername;
  final String? quotedText;

  const ReplyComposerScreen({
    super.key,
    required this.serverUrl,
    required this.topicId,
    required this.topicTitle,
    this.replyToPostNumber,
    this.replyToUsername,
    this.quotedText,
  });

  @override
  ConsumerState<ReplyComposerScreen> createState() =>
      _ReplyComposerScreenState();
}

class _ReplyComposerScreenState extends ConsumerState<ReplyComposerScreen> {
  final _bodyController = TextEditingController();
  final _bodyFocus = FocusNode();
  bool _showPreview = false;
  bool _isSubmitting = false;

  late final DraftParams _draftParams = DraftParams(
    serverUrl: widget.serverUrl,
    draftKey: 'topic_${widget.topicId}',
  );

  @override
  void initState() {
    super.initState();
    if (widget.quotedText != null && widget.replyToUsername != null) {
      _bodyController.text =
          '[quote="${widget.replyToUsername}"]\n${widget.quotedText}\n[/quote]\n\n';
      _bodyController.selection = TextSelection.collapsed(
        offset: _bodyController.text.length,
      );
    }
    _bodyController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    ref
        .read(draftProvider(_draftParams).notifier)
        .update(
          raw: _bodyController.text,
          replyToPostNumber: widget.replyToPostNumber,
        );
  }

  Future<void> _submit() async {
    final raw = _bodyController.text.trim();
    if (raw.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final authService = ref.read(authServiceProvider);
      final apiKey = await authService.loadApiKey(widget.serverUrl);
      if (apiKey == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Not authenticated')));
        }
        return;
      }

      final apiClient = ref.read(discourseApiClientProvider);
      await apiClient.createPost(
        widget.serverUrl,
        apiKey,
        raw: raw,
        topicId: widget.topicId,
        replyToPostNumber: widget.replyToPostNumber,
      );

      ref.read(draftProvider(_draftParams).notifier).discard();

      final params = TopicDetailParams(
        serverUrl: widget.serverUrl,
        topicId: widget.topicId,
      );
      ref.read(topicDetailProvider(params).notifier).refresh();

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to post reply: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool get _canSubmit => _bodyController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = ref.watch(draftProvider(_draftParams));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _confirmDiscard(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reply', style: TextStyle(fontSize: 16)),
            Text(
              widget.topicTitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (draft.isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _canSubmit && !_isSubmitting ? _submit : null,
              child:
                  _isSubmitting
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Text('Post'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          MarkdownToolbar(
            controller: _bodyController,
            previewActive: _showPreview,
            onTogglePreview: () => setState(() => _showPreview = !_showPreview),
          ),
          if (widget.replyToUsername != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Icon(
                    Icons.reply_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.replyToPostNumber != null
                          ? 'Replying to ${widget.replyToUsername} (#${widget.replyToPostNumber})'
                          : 'Replying to topic',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _showPreview ? _buildPreview(theme) : _buildEditor(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _bodyController,
        focusNode: _bodyFocus,
        autofocus: true,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: const InputDecoration(
          hintText: 'Write your reply...',
          border: InputBorder.none,
        ),
        style: theme.textTheme.bodyLarge,
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final text = _bodyController.text;
    if (text.trim().isEmpty) {
      return Center(
        child: Text(
          'Nothing to preview',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(text, style: theme.textTheme.bodyLarge),
    );
  }

  void _confirmDiscard(BuildContext context) {
    if (_bodyController.text.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Discard reply?'),
            content: const Text('Your draft will be saved automatically.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pop();
                },
                child: const Text('Discard'),
              ),
            ],
          ),
    );
  }
}
