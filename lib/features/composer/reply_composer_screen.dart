import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/providers/draft_provider.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/core/providers/topic_detail_provider.dart';
import 'package:lunaris/features/composer/composer_upload_mixin.dart';
import 'package:lunaris/features/composer/markdown_toolbar.dart';
import 'package:lunaris/ui/widgets/adaptive_dialog.dart';

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

class _ReplyComposerScreenState extends ConsumerState<ReplyComposerScreen>
    with ComposerUploadMixin {
  final _bodyController = TextEditingController();
  final _bodyFocus = FocusNode();
  bool _showPreview = false;
  bool _isSubmitting = false;

  @override
  TextEditingController get uploadBodyController => _bodyController;
  @override
  String get uploadServerUrl => widget.serverUrl;

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
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reply',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Text(
              widget.topicTitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (draft.isSaving)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _canSubmit && !_isSubmitting ? _submit : null,
              icon: _isSubmitting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isSubmitting ? 'Posting...' : 'Post',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.replyToUsername != null) _buildReplyBanner(theme),
          if (isUploading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _showPreview ? _buildPreview(theme) : _buildEditor(theme),
          ),
          MarkdownToolbar(
            controller: _bodyController,
            previewActive: _showPreview,
            onTogglePreview: () => setState(() => _showPreview = !_showPreview),
            onAttachTap: showAttachPicker,
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply_rounded,
            size: 15,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.replyToPostNumber != null
                  ? 'Replying to ${widget.replyToUsername} · #${widget.replyToPostNumber}'
                  : 'Replying to topic',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary.withValues(alpha: 0.8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _bodyController,
        focusNode: _bodyFocus,
        autofocus: true,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: InputDecoration(
          hintText: 'Write your reply...',
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
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
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SelectableText(
        text,
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
      ),
    );
  }

  void _confirmDiscard(BuildContext context) async {
    if (_bodyController.text.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final confirmed = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Discard reply?',
      content: 'Your draft will be saved automatically.',
      cancelLabel: 'Keep editing',
      confirmLabel: 'Discard',
      isDestructive: true,
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
