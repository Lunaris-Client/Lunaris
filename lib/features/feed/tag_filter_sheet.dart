import 'package:flutter/material.dart';

class TagFilterSheet extends StatefulWidget {
  final List<String> tags;
  final String? selected;

  const TagFilterSheet({super.key, required this.tags, this.selected});

  @override
  State<TagFilterSheet> createState() => _TagFilterSheetState();
}

class _TagFilterSheetState extends State<TagFilterSheet> {
  late List<String> _filteredTags;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredTags = widget.tags;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredTags = widget.tags;
      } else {
        _filteredTags =
            widget.tags
                .where((t) => t.toLowerCase().contains(query.toLowerCase()))
                .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text('Filter by Tag', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  if (widget.selected != null)
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'clear'),
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search tags...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child:
                  _filteredTags.isEmpty
                      ? Center(
                        child: Text(
                          'No tags found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                      : ListView.builder(
                        controller: scrollController,
                        itemCount: _filteredTags.length,
                        itemBuilder: (context, index) {
                          final tag = _filteredTags[index];
                          final isSelected = widget.selected == tag;

                          return ListTile(
                            selected: isSelected,
                            leading: const Icon(Icons.tag_rounded, size: 20),
                            title: Text(tag),
                            trailing:
                                isSelected
                                    ? Icon(
                                      Icons.check_rounded,
                                      color: theme.colorScheme.primary,
                                    )
                                    : null,
                            onTap: () => Navigator.pop(context, tag),
                          );
                        },
                      ),
            ),
          ],
        );
      },
    );
  }
}
