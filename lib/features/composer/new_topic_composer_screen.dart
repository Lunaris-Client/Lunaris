import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/models/site_category.dart';
import 'package:lunaris/core/providers/draft_provider.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/core/utils/color_utils.dart';
import 'package:lunaris/features/composer/markdown_toolbar.dart';

class NewTopicComposerScreen extends ConsumerStatefulWidget {
  final String serverUrl;
  final List<SiteCategory> categories;
  final List<String> topTags;
  final bool canTagTopics;
  final bool canCreateTag;

  const NewTopicComposerScreen({
    super.key,
    required this.serverUrl,
    required this.categories,
    this.topTags = const [],
    this.canTagTopics = false,
    this.canCreateTag = false,
  });

  @override
  ConsumerState<NewTopicComposerScreen> createState() =>
      _NewTopicComposerScreenState();
}

class _NewTopicComposerScreenState
    extends ConsumerState<NewTopicComposerScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _tagController = TextEditingController();
  final _bodyFocus = FocusNode();
  bool _showPreview = false;
  bool _isSubmitting = false;
  int? _selectedCategoryId;
  final List<String> _selectedTags = [];
  List<String> _tagSuggestions = [];
  Timer? _tagSearchTimer;
  List<dynamic> _similarTopics = [];
  Timer? _similarTimer;

  late final DraftParams _draftParams = DraftParams(
    serverUrl: widget.serverUrl,
    draftKey: 'new_topic',
  );

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
    _bodyController.addListener(_onBodyChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagController.dispose();
    _bodyFocus.dispose();
    _tagSearchTimer?.cancel();
    _similarTimer?.cancel();
    super.dispose();
  }

  void _onTitleChanged() {
    _updateDraft();
    _scheduleSimilarSearch();
  }

  void _onBodyChanged() {
    _updateDraft();
  }

  void _updateDraft() {
    ref
        .read(draftProvider(_draftParams).notifier)
        .update(
          raw: _bodyController.text,
          title: _titleController.text,
          categoryId: _selectedCategoryId,
          tags: _selectedTags,
        );
  }

  void _scheduleSimilarSearch() {
    _similarTimer?.cancel();
    final title = _titleController.text.trim();
    if (title.length < 5) {
      setState(() => _similarTopics = []);
      return;
    }
    _similarTimer = Timer(const Duration(milliseconds: 800), () async {
      try {
        final authService = ref.read(authServiceProvider);
        final apiKey = await authService.loadApiKey(widget.serverUrl);
        if (apiKey == null) return;
        final apiClient = ref.read(discourseApiClientProvider);
        final results = await apiClient.searchSimilarTopics(
          widget.serverUrl,
          apiKey,
          title: title,
        );
        if (mounted) setState(() => _similarTopics = results.take(5).toList());
      } catch (_) {}
    });
  }

  Future<void> _searchTags(String query) async {
    _tagSearchTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _tagSuggestions = []);
      return;
    }
    _tagSearchTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final authService = ref.read(authServiceProvider);
        final apiKey = await authService.loadApiKey(widget.serverUrl);
        if (apiKey == null) return;
        final apiClient = ref.read(discourseApiClientProvider);
        final results = await apiClient.searchTags(
          widget.serverUrl,
          apiKey,
          query: query.trim(),
        );
        if (mounted) {
          setState(() {
            _tagSuggestions =
                results
                    .map((r) => (r as Map)['name']?.toString() ?? '')
                    .where((t) => t.isNotEmpty && !_selectedTags.contains(t))
                    .toList();
          });
        }
      } catch (_) {}
    });
  }

  void _addTag(String tag) {
    if (_selectedTags.contains(tag)) return;
    setState(() {
      _selectedTags.add(tag);
      _tagController.clear();
      _tagSuggestions = [];
    });
    _updateDraft();
  }

  void _removeTag(String tag) {
    setState(() => _selectedTags.remove(tag));
    _updateDraft();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final raw = _bodyController.text.trim();
    if (title.isEmpty || raw.isEmpty) return;

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
        title: title,
        categoryId: _selectedCategoryId,
        tags: _selectedTags.isNotEmpty ? _selectedTags : null,
      );

      ref.read(draftProvider(_draftParams).notifier).discard();

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create topic: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty &&
      _bodyController.text.trim().isNotEmpty;

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
        title: const Text('New Topic', style: TextStyle(fontSize: 16)),
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
                      : const Text('Create'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMetadataSection(theme),
          MarkdownToolbar(
            controller: _bodyController,
            previewActive: _showPreview,
            onTogglePreview: () => setState(() => _showPreview = !_showPreview),
          ),
          Expanded(
            child: _showPreview ? _buildPreview(theme) : _buildEditor(theme),
          ),
          if (_similarTopics.isNotEmpty) _buildSimilarTopics(theme),
        ],
      ),
    );
  }

  Widget _buildMetadataSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Topic title',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _bodyFocus.requestFocus(),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildCategorySelector(theme)),
                if (widget.canTagTopics) ...[
                  const SizedBox(width: 12),
                  Expanded(child: _buildTagInput(theme)),
                ],
              ],
            ),
          ),
          if (_selectedTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children:
                    _selectedTags
                        .map(
                          (tag) => InputChip(
                            label: Text(tag),
                            onDeleted: () => _removeTag(tag),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
              ),
            ),
          if (_tagSuggestions.isNotEmpty) _buildTagSuggestions(theme),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(ThemeData theme) {
    final writableCategories =
        widget.categories.where((c) => !c.readRestricted).toList();

    return DropdownButtonFormField<int?>(
      initialValue: _selectedCategoryId,
      decoration: const InputDecoration(
        hintText: 'Category',
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
      ),
      isExpanded: true,
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('No category')),
        ...writableCategories.map((cat) {
          final color = parseHexColor(cat.color);
          return DropdownMenuItem<int?>(
            value: cat.id,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    cat.name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
      onChanged: (value) {
        setState(() => _selectedCategoryId = value);
        _updateDraft();
      },
    );
  }

  Widget _buildTagInput(ThemeData theme) {
    return TextField(
      controller: _tagController,
      decoration: const InputDecoration(
        hintText: 'Add tags...',
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
      ),
      onChanged: _searchTags,
      onSubmitted: (value) {
        if (value.trim().isNotEmpty) _addTag(value.trim());
      },
    );
  }

  Widget _buildTagSuggestions(ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _tagSuggestions.length,
        itemBuilder: (context, index) {
          final tag = _tagSuggestions[index];
          return ListTile(
            dense: true,
            title: Text(tag),
            onTap: () => _addTag(tag),
          );
        },
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
          hintText: 'Write your topic content...',
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

  Widget _buildSimilarTopics(ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Similar topics',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _similarTopics.length,
              itemBuilder: (context, index) {
                final topic = _similarTopics[index];
                final title =
                    topic is Map
                        ? (topic['title'] ?? topic['fancy_title'] ?? '')
                            .toString()
                        : topic.toString();
                return ListTile(
                  dense: true,
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  leading: Icon(
                    Icons.topic_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDiscard(BuildContext context) {
    if (_titleController.text.trim().isEmpty &&
        _bodyController.text.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Discard topic?'),
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
