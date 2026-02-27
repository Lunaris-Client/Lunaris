import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/providers/draft_provider.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/features/composer/composer_upload_mixin.dart';
import 'package:lunaris/features/composer/markdown_toolbar.dart';
import 'package:lunaris/ui/widgets/adaptive_dialog.dart';

class PmComposerScreen extends ConsumerStatefulWidget {
  final String serverUrl;

  const PmComposerScreen({
    super.key,
    required this.serverUrl,
  });

  @override
  ConsumerState<PmComposerScreen> createState() => _PmComposerScreenState();
}

class _PmComposerScreenState extends ConsumerState<PmComposerScreen>
    with ComposerUploadMixin {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _recipientController = TextEditingController();
  final _bodyFocus = FocusNode();
  bool _showPreview = false;
  bool _isSubmitting = false;

  final List<String> _recipients = [];
  List<dynamic> _userSuggestions = [];
  Timer? _userSearchTimer;

  @override
  TextEditingController get uploadBodyController => _bodyController;
  @override
  String get uploadServerUrl => widget.serverUrl;

  late final DraftParams _draftParams = DraftParams(
    serverUrl: widget.serverUrl,
    draftKey: 'new_private_message',
  );

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_updateDraft);
    _bodyController.addListener(_updateDraft);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _recipientController.dispose();
    _bodyFocus.dispose();
    _userSearchTimer?.cancel();
    super.dispose();
  }

  void _updateDraft() {
    ref
        .read(draftProvider(_draftParams).notifier)
        .update(raw: _bodyController.text, title: _titleController.text);
  }

  Future<void> _searchUsers(String query) async {
    _userSearchTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _userSuggestions = []);
      return;
    }
    _userSearchTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final authService = ref.read(authServiceProvider);
        final apiKey = await authService.loadApiKey(widget.serverUrl);
        if (apiKey == null) return;
        final apiClient = ref.read(discourseApiClientProvider);
        final results = await apiClient.searchUsers(
          widget.serverUrl,
          apiKey,
          term: query.trim(),
          includeGroups: true,
        );
        if (mounted) setState(() => _userSuggestions = results);
      } catch (_) {
        if (mounted) setState(() => _userSuggestions = []);
      }
    });
  }

  void _addRecipient(String username) {
    if (!_recipients.contains(username)) {
      setState(() {
        _recipients.add(username);
        _recipientController.clear();
        _userSuggestions = [];
      });
      _updateDraft();
    }
  }

  void _removeRecipient(String username) {
    setState(() => _recipients.remove(username));
    _updateDraft();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final raw = _bodyController.text.trim();
    if (title.isEmpty || raw.isEmpty || _recipients.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final authService = ref.read(authServiceProvider);
      final apiKey = await authService.loadApiKey(widget.serverUrl);
      if (apiKey == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not authenticated')),
          );
        }
        return;
      }

      final apiClient = ref.read(discourseApiClientProvider);
      await apiClient.createPost(
        widget.serverUrl,
        apiKey,
        raw: raw,
        title: title,
        archetype: 'private_message',
        targetRecipients: _recipients.join(','),
      );

      ref.read(draftProvider(_draftParams).notifier).discard();

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty &&
      _bodyController.text.trim().isNotEmpty &&
      _recipients.isNotEmpty;

  Future<bool> _onWillPop() async {
    final hasContent = _titleController.text.trim().isNotEmpty ||
        _bodyController.text.trim().isNotEmpty ||
        _recipients.isNotEmpty;
    if (!hasContent) return true;
    final result = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Discard message?',
      content: 'Your draft will be saved automatically.',
      cancelLabel: 'Keep editing',
      confirmLabel: 'Discard',
      isDestructive: true,
    );
    if (result == true) {
      ref.read(draftProvider(_draftParams).notifier).discard();
    }
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.watch(draftProvider(_draftParams));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _onWillPop()) {
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: const Text(
            'New Message',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
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
                  _isSubmitting ? 'Sending...' : 'Send',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                onPressed: _canSubmit && !_isSubmitting ? _submit : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildRecipientsSection(theme),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
            _buildTitleField(theme),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
            if (isUploading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _showPreview ? _buildPreview(theme) : _buildEditor(theme),
            ),
            MarkdownToolbar(
              controller: _bodyController,
              previewActive: _showPreview,
              onTogglePreview: () =>
                  setState(() => _showPreview = !_showPreview),
              onAttachTap: showAttachPicker,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientsSection(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.3),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recipients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final r in _recipients)
                    InputChip(
                      label: Text(r, style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => _removeRecipient(r),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      deleteIconColor:
                          theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                ],
              ),
            ),
          TextField(
            controller: _recipientController,
            decoration: InputDecoration(
              hintText: 'Add a recipient...',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 13,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            style: theme.textTheme.bodyMedium,
            onChanged: _searchUsers,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) _addRecipient(value.trim());
            },
          ),
          if (_userSuggestions.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _userSuggestions.length,
                itemBuilder: (context, index) {
                  final user = _userSuggestions[index] as Map<String, dynamic>;
                  final username = user['username'] as String? ?? '';
                  final name = user['name'] as String?;
                  final avatar = user['avatar_template'] as String?;
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: avatar != null
                        ? CircleAvatar(
                            radius: 14,
                            backgroundImage: NetworkImage(
                              avatar.startsWith('http')
                                  ? avatar.replaceAll('{size}', '40')
                                  : '${widget.serverUrl}${avatar.replaceAll('{size}', '40')}',
                            ),
                          )
                        : CircleAvatar(
                            radius: 14,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.person,
                              size: 14,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                    title: Text(username, style: const TextStyle(fontSize: 13)),
                    subtitle: name != null && name.isNotEmpty
                        ? Text(
                            name,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        : null,
                    onTap: () => _addRecipient(username),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTitleField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _titleController,
        decoration: InputDecoration(
          hintText: 'Message title',
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          isDense: true,
        ),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => _bodyFocus.requestFocus(),
      ),
    );
  }

  Widget _buildEditor(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _bodyController,
        focusNode: _bodyFocus,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: InputDecoration(
          hintText: 'Write your message...',
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
    final raw = _bodyController.text;
    if (raw.trim().isEmpty) {
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
        raw,
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
      ),
    );
  }
}
