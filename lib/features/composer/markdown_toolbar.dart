import 'package:flutter/material.dart';

class MarkdownToolbar extends StatelessWidget {
  final TextEditingController controller;
  final bool showPreviewToggle;
  final bool previewActive;
  final VoidCallback? onTogglePreview;
  final VoidCallback? onAttachTap;

  const MarkdownToolbar({
    super.key,
    required this.controller,
    this.showPreviewToggle = true,
    this.previewActive = false,
    this.onTogglePreview,
    this.onAttachTap,
  });

  void _wrap(String before, String after, {String placeholder = 'text'}) {
    final sel = controller.selection;
    final text = controller.text;

    if (sel.isValid && sel.start != sel.end) {
      final selected = text.substring(sel.start, sel.end);
      final replacement = '$before$selected$after';
      controller.text = text.replaceRange(sel.start, sel.end, replacement);
      controller.selection = TextSelection(
        baseOffset: sel.start + before.length,
        extentOffset: sel.start + before.length + selected.length,
      );
    } else {
      final offset = sel.isValid ? sel.start : text.length;
      final replacement = '$before$placeholder$after';
      controller.text = text.replaceRange(offset, offset, replacement);
      controller.selection = TextSelection(
        baseOffset: offset + before.length,
        extentOffset: offset + before.length + placeholder.length,
      );
    }
  }

  void _prefixLine(String prefix) {
    final sel = controller.selection;
    final text = controller.text;
    final offset = sel.isValid ? sel.start : text.length;

    final lineStart = text.lastIndexOf('\n', offset > 0 ? offset - 1 : 0) + 1;
    controller.text = text.replaceRange(lineStart, lineStart, prefix);
    controller.selection = TextSelection.collapsed(
      offset: offset + prefix.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  _ToolbarButton(
                    icon: Icons.format_bold_rounded,
                    tooltip: 'Bold',
                    onTap: () => _wrap('**', '**', placeholder: 'bold'),
                  ),
                  _ToolbarButton(
                    icon: Icons.format_italic_rounded,
                    tooltip: 'Italic',
                    onTap: () => _wrap('*', '*', placeholder: 'italic'),
                  ),
                  _ToolbarButton(
                    icon: Icons.link_rounded,
                    tooltip: 'Link',
                    onTap: () =>
                        _wrap('[', '](url)', placeholder: 'link text'),
                  ),
                  _ToolbarButton(
                    icon: Icons.image_outlined,
                    tooltip: 'Image',
                    onTap: () =>
                        _wrap('![', '](url)', placeholder: 'alt text'),
                  ),
                  if (onAttachTap != null)
                    _ToolbarButton(
                      icon: Icons.attach_file_rounded,
                      tooltip: 'Attach file',
                      onTap: onAttachTap,
                    ),
                  _ToolbarButton(
                    icon: Icons.format_quote_rounded,
                    tooltip: 'Quote',
                    onTap: () => _prefixLine('> '),
                  ),
                  _ToolbarButton(
                    icon: Icons.code_rounded,
                    tooltip: 'Code',
                    onTap: () => _wrap('`', '`', placeholder: 'code'),
                  ),
                  _ToolbarButton(
                    icon: Icons.format_list_bulleted_rounded,
                    tooltip: 'List',
                    onTap: () => _prefixLine('- '),
                  ),
                  _ToolbarButton(
                    icon: Icons.title_rounded,
                    tooltip: 'Heading',
                    onTap: () => _prefixLine('## '),
                  ),
                ],
              ),
            ),
          ),
          if (showPreviewToggle) ...[
            SizedBox(
              height: 24,
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _ToolbarButton(
                icon: previewActive
                    ? Icons.edit_rounded
                    : Icons.visibility_rounded,
                tooltip: previewActive ? 'Edit' : 'Preview',
                onTap: onTogglePreview,
                highlighted: previewActive,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool highlighted;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        icon: Icon(
          icon,
          size: 19,
          color: highlighted
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        tooltip: tooltip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        splashRadius: 16,
        style: highlighted
            ? IconButton.styleFrom(
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              )
            : null,
      ),
    );
  }
}
