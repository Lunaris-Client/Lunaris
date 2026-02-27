import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/models/chat_channel.dart';
import 'package:lunaris/core/providers/chat_provider.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/core/utils/color_utils.dart';
import 'package:lunaris/features/chat/chat_channel_screen.dart';

class NewChatScreen extends ConsumerStatefulWidget {
  final String serverUrl;

  const NewChatScreen({super.key, required this.serverUrl});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _searchController = TextEditingController();
  final _groupNameController = TextEditingController();
  final _searchFocus = FocusNode();
  List<Map<String, dynamic>> _searchResults = [];
  final List<Map<String, dynamic>> _selectedUsers = [];
  bool _isSearching = false;
  bool _isCreating = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchFocus.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String term) async {
    if (term.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final apiKey =
          await ref.read(authServiceProvider).loadApiKey(widget.serverUrl);
      if (apiKey == null) return;

      final results = await ref.read(discourseApiClientProvider).searchUsers(
            widget.serverUrl,
            apiKey,
            term: term,
          );

      if (!mounted) return;

      final selectedNames =
          _selectedUsers.map((u) => u['username'] as String).toSet();

      setState(() {
        _searchResults = results
            .cast<Map<String, dynamic>>()
            .where((u) => !selectedNames.contains(u['username'] as String?))
            .toList();
        _isSearching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(value);
    });
  }

  void _addUser(Map<String, dynamic> user) {
    setState(() {
      _selectedUsers.add(user);
      _searchResults
          .removeWhere((u) => u['username'] == user['username']);
      _searchController.clear();
      _searchResults = [];
    });
    _searchFocus.requestFocus();
  }

  void _removeUser(Map<String, dynamic> user) {
    setState(() {
      _selectedUsers
          .removeWhere((u) => u['username'] == user['username']);
    });
  }

  Future<void> _createChannel() async {
    if (_selectedUsers.isEmpty) return;

    setState(() => _isCreating = true);

    try {
      final apiKey =
          await ref.read(authServiceProvider).loadApiKey(widget.serverUrl);
      if (apiKey == null) return;

      final usernames =
          _selectedUsers.map((u) => u['username'] as String).toList();

      final result =
          await ref.read(discourseApiClientProvider).createDirectMessageChannel(
                widget.serverUrl,
                apiKey,
                targetUsernames: usernames,
                name: _selectedUsers.length > 1
                    ? _groupNameController.text.trim().isNotEmpty
                        ? _groupNameController.text.trim()
                        : null
                    : null,
              );

      if (!mounted) return;

      final channelData = result['channel'] as Map<String, dynamic>?;
      if (channelData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create channel')),
          );
        }
        setState(() => _isCreating = false);
        return;
      }

      final channel = ChatChannel.fromJson(channelData);

      ref.read(chatChannelListProvider(widget.serverUrl).notifier).refresh();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ChatChannelScreen(
              serverUrl: widget.serverUrl,
              channel: channel,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create chat: $e')),
        );
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGroup = _selectedUsers.length > 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New message'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed:
                  _selectedUsers.isNotEmpty && !_isCreating ? _createChannel : null,
              child: _isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Start'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedUsers.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _selectedUsers
                    .map((user) => InputChip(
                          avatar: _buildUserAvatar(user, 14),
                          label: Text(user['username'] as String? ?? ''),
                          onDeleted: () => _removeUser(user),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ),
          if (isGroup)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _groupNameController,
                decoration: const InputDecoration(
                  hintText: 'Group name (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search for a user...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchResults = []);
                            },
                          )
                        : null,
              ),
            ),
          ),
          Expanded(
            child: _searchResults.isEmpty && _searchController.text.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Search for people to message',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : _searchResults.isEmpty && !_isSearching
                    ? Center(
                        child: Text(
                          'No users found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          return _UserTile(
                            user: user,
                            serverUrl: widget.serverUrl,
                            onTap: () => _addUser(user),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(Map<String, dynamic> user, double radius) {
    final template = user['avatar_template'] as String?;
    if (template != null) {
      final url =
          resolveAvatarUrl(widget.serverUrl, template, size: (radius * 2).toInt());
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(url),
      );
    }
    final username = user['username'] as String? ?? '?';
    return CircleAvatar(
      radius: radius,
      child: Text(username[0].toUpperCase()),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final String serverUrl;
  final VoidCallback onTap;

  const _UserTile({
    required this.user,
    required this.serverUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final username = user['username'] as String? ?? '';
    final name = user['name'] as String?;
    final template = user['avatar_template'] as String?;

    return ListTile(
      onTap: onTap,
      leading: template != null
          ? CircleAvatar(
              backgroundImage: NetworkImage(
                resolveAvatarUrl(serverUrl, template, size: 40),
              ),
            )
          : CircleAvatar(child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?')),
      title: Text(username),
      subtitle: name != null && name.isNotEmpty && name != username
          ? Text(
              name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: const Icon(Icons.add_rounded),
    );
  }
}
