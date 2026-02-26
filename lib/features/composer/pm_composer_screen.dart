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
          title: const Text('New Message'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: _isSubmitting
                    ? const Text('Sending...')
                    : const Text('Send'),
                onPressed: _canSubmit && !_isSubmitting ? _submit : null,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildRecipientsSection(theme),
            const Divider(height: 1),
            _buildTitleField(theme),
            const Divider(height: 1),
            MarkdownToolbar(
              controller: _bodyController,
              previewActive: _showPreview,
              onTogglePreview: () =>
                  setState(() => _showPreview = !_showPreview),
              onAttachTap: showAttachPicker,
            ),
            if (isUploading) const LinearProgressIndicator(),
            Expanded(
              child: _showPreview ? _buildPreview(theme) : _buildEditor(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientsSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final r in _recipients)
                Chip(
                  label: Text(r),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => _removeRecipient(r),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          TextField(
            controller: _recipientController,
            decoration: const InputDecoration(
              hintText: 'Add a recipient...',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: _searchUsers,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) _addRecipient(value.trim());
            },
          ),
          if (_userSuggestions.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _userSuggestions.length,
                itemBuilder: (context, index) {
                  final user = _userSuggestions[index] as Map<String, dynamic>;
                  final username = user['username'] as String? ?? '';
                  final name = user['name'] as String?;
                  final avatar = user['avatar_template'] as String?;
                  return ListTile(
                    dense: true,
                    leading: avatar != null
                        ? CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage(
                              avatar.startsWith('http')
                                  ? avatar.replaceAll('{size}', '40')
                                  : '${widget.serverUrl}${avatar.replaceAll('{size}', '40')}',
                            ),
                          )
                        : const CircleAvatar(
                            radius: 16,
                            child: Icon(Icons.person, size: 18),
                          ),
                    title: Text(username),
                    subtitle: name != null && name.isNotEmpty
                        ? Text(name)
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
        decoration: const InputDecoration(
          hintText: 'Message title',
          border: InputBorder.none,
          isDense: true,
        ),
        style: theme.textTheme.titleMedium,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => _bodyFocus.requestFocus(),
      ),
    );
  }

  Widget _buildEditor(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _bodyController,
        focusNode: _bodyFocus,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: const InputDecoration(
          hintText: 'Write your message...',
          border: InputBorder.none,
        ),
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final raw = _bodyController.text;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: raw.isEmpty
          ? Text(
              'Nothing to preview',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            )
          : SelectableText(
              raw,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
    );
  }
}
