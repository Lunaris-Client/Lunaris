import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/models/search_result.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/core/providers/search_provider.dart';
import 'package:lunaris/core/utils/color_utils.dart';
import 'package:timeago/timeago.dart' as timeago;

class SearchScreen extends ConsumerStatefulWidget {
  final String serverUrl;
  final void Function(int topicId)? onTopicTap;
  final void Function(String username)? onUserTap;

  const SearchScreen({
    super.key,
    required this.serverUrl,
    this.onTopicTap,
    this.onUserTap,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<String> _recentSearches = [];

  static String _recentKey(String serverUrl) =>
      'recent_searches_$serverUrl';

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadRecentSearches() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final stored = prefs.getStringList(_recentKey(widget.serverUrl));
      if (stored != null) {
        setState(() => _recentSearches = stored);
      }
    } catch (_) {}
  }

  Future<void> _saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.sublist(0, 10);
    }
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setStringList(
          _recentKey(widget.serverUrl), _recentSearches);
    } catch (_) {}
  }

  void _onSubmitted(String query) {
    if (query.trim().isEmpty) return;
    _saveRecentSearch(query.trim());
    ref.read(searchProvider(widget.serverUrl).notifier).search(query.trim());
  }

  void _onChanged(String query) {
    ref.read(searchProvider(widget.serverUrl).notifier).search(query);
  }

  void _clearSearch() {
    _controller.clear();
    ref.read(searchProvider(widget.serverUrl).notifier).clear();
    _focusNode.requestFocus();
  }

  void _useRecentSearch(String query) {
    _controller.text = query;
    _controller.selection =
        TextSelection.collapsed(offset: query.length);
    _onSubmitted(query);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider(widget.serverUrl));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          onSubmitted: _onSubmitted,
          decoration: InputDecoration(
            hintText: 'Search topics, posts, users...',
            border: InputBorder.none,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    onPressed: _clearSearch,
                  )
                : null,
          ),
          textInputAction: TextInputAction.search,
        ),
      ),
      body: _buildBody(state, theme),
    );
  }

  Widget _buildBody(SearchState state, ThemeData theme) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48,
                  color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text('Search failed', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('${state.error}',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
    }

    if (state.query.isEmpty) {
      return _buildRecentSearches(theme);
    }

    if (state.result == null || state.result!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('No results found',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ],
        ),
      );
    }

    return _buildResults(state.result!, theme);
  }

  Widget _buildRecentSearches(ThemeData theme) {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 64,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Search this site',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
            const SizedBox(height: 8),
            Text('Try @username, #category, or tag:name',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                )),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('Recent searches',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
        ),
        for (final query in _recentSearches)
          ListTile(
            leading: const Icon(Icons.history_rounded, size: 20),
            title: Text(query),
            dense: true,
            onTap: () => _useRecentSearch(query),
          ),
      ],
    );
  }

  Widget _buildResults(SearchResult result, ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (result.users.isNotEmpty) ...[
          _SectionHeader(title: 'Users', count: result.users.length),
          for (final user in result.users)
            _UserResultTile(
              user: user,
              serverUrl: widget.serverUrl,
              onTap: () => widget.onUserTap?.call(user.username),
            ),
        ],
        if (result.topics.isNotEmpty) ...[
          _SectionHeader(title: 'Topics', count: result.topics.length),
          for (final topic in result.topics)
            _TopicResultTile(
              topic: topic,
              onTap: () => widget.onTopicTap?.call(topic.id),
            ),
        ],
        if (result.posts.isNotEmpty) ...[
          _SectionHeader(title: 'Posts', count: result.posts.length),
          for (final post in result.posts)
            _PostResultTile(
              post: post,
              serverUrl: widget.serverUrl,
              onTap: () => widget.onTopicTap?.call(post.topicId),
            ),
        ],
        if (result.categories.isNotEmpty) ...[
          _SectionHeader(
              title: 'Categories', count: result.categories.length),
          for (final category in result.categories)
            _CategoryResultTile(category: category),
        ],
        if (result.tags.isNotEmpty) ...[
          _SectionHeader(title: 'Tags', count: result.tags.length),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: result.tags
                  .map((t) => Chip(
                        label: Text(t),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
        ],
      ),
    );
  }
}

class _UserResultTile extends StatelessWidget {
  final SearchUser user;
  final String serverUrl;
  final VoidCallback? onTap;

  const _UserResultTile({
    required this.user,
    required this.serverUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundImage: user.avatarTemplate != null
            ? NetworkImage(
                resolveAvatarUrl(serverUrl, user.avatarTemplate!, size: 40))
            : null,
        child: user.avatarTemplate == null
            ? const Icon(Icons.person_rounded)
            : null,
      ),
      title: Text(user.username),
      subtitle: user.name != null && user.name!.isNotEmpty
          ? Text(user.name!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ))
          : null,
      onTap: onTap,
    );
  }
}

class _TopicResultTile extends StatelessWidget {
  final SearchTopic topic;
  final VoidCallback? onTap;

  const _TopicResultTile({required this.topic, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(topic.fancyTitle ?? topic.title,
          maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Text('${topic.postsCount} posts',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          const SizedBox(width: 8),
          Text('${topic.views} views',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          if (topic.bumpedAt != null) ...[
            const SizedBox(width: 8),
            Text(timeago.format(topic.bumpedAt!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ],
        ],
      ),
      trailing: topic.closed
          ? Icon(Icons.lock_rounded,
              size: 16, color: theme.colorScheme.onSurfaceVariant)
          : null,
      onTap: onTap,
    );
  }
}

class _PostResultTile extends StatelessWidget {
  final SearchPost post;
  final String serverUrl;
  final VoidCallback? onTap;

  const _PostResultTile({
    required this.post,
    required this.serverUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundImage: post.avatarTemplate != null
            ? NetworkImage(
                resolveAvatarUrl(serverUrl, post.avatarTemplate!, size: 32))
            : null,
        child: post.avatarTemplate == null
            ? const Icon(Icons.person_rounded, size: 16)
            : null,
      ),
      title: Text(post.topicTitle ?? 'Post #${post.postNumber}',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stripHtml(post.blurb),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(post.username,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
        ],
      ),
      isThreeLine: true,
      onTap: onTap,
    );
  }
}

class _CategoryResultTile extends StatelessWidget {
  final SearchCategory category;

  const _CategoryResultTile({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(category.color);
    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      title: Text(category.name),
    );
  }
}
