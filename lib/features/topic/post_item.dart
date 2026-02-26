import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lunaris/core/models/post.dart';
import 'package:lunaris/core/utils/color_utils.dart';
import 'package:lunaris/features/topic/cooked_html_renderer.dart';
import 'package:lunaris/features/topic/full_screen_image_viewer.dart';

class PostItem extends StatefulWidget {
  final Post post;
  final String serverUrl;
  final VoidCallback? onLikeTap;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onBookmarkLongPress;
  final VoidCallback? onShareTap;
  final VoidCallback? onReplyTap;
  final ValueChanged<int>? onReplyToTap;
  final bool showReplyIndicator;

  const PostItem({
    super.key,
    required this.post,
    required this.serverUrl,
    this.onLikeTap,
    this.onBookmarkTap,
    this.onBookmarkLongPress,
    this.onShareTap,
    this.onReplyTap,
    this.onReplyToTap,
    this.showReplyIndicator = true,
  });

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  bool _showAbsoluteTime = false;

  Post get post => widget.post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAuthorRow(theme),
          if (widget.showReplyIndicator && post.replyToPostNumber != null)
            _buildReplyIndicator(theme),
          const SizedBox(height: 8),
          _buildContent(),
          const SizedBox(height: 8),
          _buildActionBar(theme),
        ],
      ),
    );
  }

  Widget _buildAuthorRow(ThemeData theme) {
    final avatarUrl =
        post.avatarTemplate != null
            ? resolveAvatarUrl(widget.serverUrl, post.avatarTemplate!, size: 40)
            : null;

    return Row(
      children: [
        if (avatarUrl != null)
          CircleAvatar(
            radius: 18,
            backgroundImage: CachedNetworkImageProvider(avatarUrl),
          )
        else
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              size: 18,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      post.name?.isNotEmpty == true
                          ? post.name!
                          : post.username,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (post.admin || post.moderator) ...[
                    const SizedBox(width: 4),
                    _buildStaffBadge(theme),
                  ],
                ],
              ),
              Row(
                children: [
                  if (post.name?.isNotEmpty == true) ...[
                    Text(
                      post.username,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (post.userTitle != null && post.userTitle!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color:
                            post.flairBgColor != null
                                ? parseHexColor(
                                  post.flairBgColor!,
                                ).withValues(alpha: 0.15)
                                : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        post.userTitle!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color:
                              post.flairColor != null
                                  ? parseHexColor(post.flairColor!)
                                  : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  GestureDetector(
                    onTap:
                        () => setState(
                          () => _showAbsoluteTime = !_showAbsoluteTime,
                        ),
                    child: Text(
                      _showAbsoluteTime
                          ? _formatAbsolute(post.createdAt)
                          : timeago.format(post.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Text(
          '#${post.postNumber}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildStaffBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color:
            post.admin
                ? theme.colorScheme.error.withValues(alpha: 0.12)
                : theme.colorScheme.tertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        post.admin ? 'admin' : 'mod',
        style: theme.textTheme.labelSmall?.copyWith(
          color:
              post.admin ? theme.colorScheme.error : theme.colorScheme.tertiary,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildReplyIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 46, top: 4),
      child: InkWell(
        onTap: () => widget.onReplyToTap?.call(post.replyToPostNumber!),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.reply_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'reply to #${post.replyToPostNumber}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.only(left: 46),
      child: CookedHtmlRenderer(
        html: post.cooked,
        serverUrl: widget.serverUrl,
        onImageTap: (url) => FullScreenImageViewer.show(context, url),
      ),
    );
  }

  Widget _buildActionBar(ThemeData theme) {
    final liked = post.actionsSummary.any((a) => a.id == 2 && a.acted);
    final canLike = post.actionsSummary.any((a) => a.id == 2 && a.canAct);

    return Padding(
      padding: const EdgeInsets.only(left: 46),
      child: Row(
        children: [
          _ActionButton(
            icon:
                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            label: post.likeCount > 0 ? formatCount(post.likeCount) : null,
            color: liked ? theme.colorScheme.error : null,
            onTap: canLike || liked ? widget.onLikeTap : null,
          ),
          if (post.replyCount > 0)
            _ActionButton(
              icon: Icons.comment_outlined,
              label: formatCount(post.replyCount),
              onTap: null,
            ),
          _ActionButton(
            icon:
                post.bookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
            color: post.bookmarked ? theme.colorScheme.primary : null,
            onTap: widget.onBookmarkTap,
            onLongPress: widget.onBookmarkLongPress,
          ),
          _ActionButton(icon: Icons.share_outlined, onTap: widget.onShareTap),
          _ActionButton(icon: Icons.reply_rounded, onTap: widget.onReplyTap),
          if (post.wiki)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.edit_note_rounded,
                size: 16,
                color: theme.colorScheme.tertiary,
              ),
            ),
        ],
      ),
    );
  }

  String _formatAbsolute(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color? color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _ActionButton({
    required this.icon,
    this.label,
    this.color,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor =
        color ?? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: effectiveColor),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: effectiveColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
