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
  final bool isStaff;
  final VoidCallback? onDeleteTap;
  final VoidCallback? onRecoverTap;
  final VoidCallback? onFlagTap;
  final VoidCallback? onAcceptAnswerTap;
  final ValueChanged<String>? onUserTap;

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
    this.isStaff = false,
    this.onDeleteTap,
    this.onRecoverTap,
    this.onFlagTap,
    this.onAcceptAnswerTap,
    this.onUserTap,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAuthorRow(theme),
          if (post.acceptedAnswer)
            _buildAcceptedBadge(theme),
          if (widget.showReplyIndicator && post.replyToPostNumber != null)
            _buildReplyIndicator(theme),
          const SizedBox(height: 10),
          _buildContent(),
          const SizedBox(height: 6),
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

    final secondaryColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

    return Row(
      children: [
        GestureDetector(
          onTap: () => widget.onUserTap?.call(post.username),
          child: avatarUrl != null
              ? CircleAvatar(
                  radius: 16,
                  backgroundImage: CachedNetworkImageProvider(avatarUrl),
                )
              : CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    size: 16,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: GestureDetector(
                  onTap: () => widget.onUserTap?.call(post.username),
                  child: Text(
                    post.name?.isNotEmpty == true
                        ? post.name!
                        : post.username,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (post.admin || post.moderator) ...[
                const SizedBox(width: 4),
                _buildStaffBadge(theme),
              ],
              if (post.userTitle != null && post.userTitle!.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  flex: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: post.flairBgColor != null
                          ? parseHexColor(post.flairBgColor!).withValues(alpha: 0.12)
                          : theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      post.userTitle!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: post.flairColor != null
                            ? parseHexColor(post.flairColor!)
                            : theme.colorScheme.primary,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _showAbsoluteTime = !_showAbsoluteTime),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  child: Text(
                    _showAbsoluteTime
                        ? _formatAbsolute(post.createdAt)
                        : timeago.format(post.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: secondaryColor,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
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

  Widget _buildAcceptedBadge(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 42, top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
          const SizedBox(width: 4),
          Text(
            'Accepted Answer',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 42, top: 4),
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
      padding: const EdgeInsets.only(left: 42),
      child: CookedHtmlRenderer(
        html: post.cooked,
        serverUrl: widget.serverUrl,
        onMentionTap: (username) => widget.onUserTap?.call(username),
        onImageTap: (url) => FullScreenImageViewer.show(context, url),
      ),
    );
  }

  Widget _buildActionBar(ThemeData theme) {
    final liked = post.actionsSummary.any((a) => a.id == 2 && a.acted);
    final canLike = post.actionsSummary.any((a) => a.id == 2 && a.canAct);

    return Padding(
      padding: const EdgeInsets.only(left: 42),
      child: Row(
        children: [
          _ActionButton(
            icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            label: post.likeCount > 0 ? formatCount(post.likeCount) : null,
            color: liked ? theme.colorScheme.error : null,
            onTap: canLike || liked ? widget.onLikeTap : null,
          ),
          if (post.replyCount > 0)
            _ActionButton(
              icon: Icons.chat_bubble_outline_rounded,
              label: formatCount(post.replyCount),
              onTap: null,
            ),
          _ActionButton(
            icon: post.bookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: post.bookmarked ? theme.colorScheme.primary : null,
            onTap: widget.onBookmarkTap,
            onLongPress: widget.onBookmarkLongPress,
          ),
          _ActionButton(icon: Icons.reply_rounded, onTap: widget.onReplyTap),
          if (!post.hidden || widget.isStaff)
            _PostOverflowMenu(
              post: post,
              isStaff: widget.isStaff,
              onDeleteTap: widget.onDeleteTap,
              onRecoverTap: widget.onRecoverTap,
              onFlagTap: widget.onFlagTap,
              onAcceptAnswerTap: widget.onAcceptAnswerTap,
              onShareTap: widget.onShareTap,
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
        color ?? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.78);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        mouseCursor: onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PostOverflowMenu extends StatelessWidget {
  final Post post;
  final bool isStaff;
  final VoidCallback? onDeleteTap;
  final VoidCallback? onRecoverTap;
  final VoidCallback? onFlagTap;
  final VoidCallback? onAcceptAnswerTap;
  final VoidCallback? onShareTap;

  const _PostOverflowMenu({
    required this.post,
    required this.isStaff,
    this.onDeleteTap,
    this.onRecoverTap,
    this.onFlagTap,
    this.onAcceptAnswerTap,
    this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 16,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      onSelected: (value) {
        switch (value) {
          case 'share':
            onShareTap?.call();
          case 'delete':
            onDeleteTap?.call();
          case 'recover':
            onRecoverTap?.call();
          case 'flag':
            onFlagTap?.call();
          case 'accept_answer':
            onAcceptAnswerTap?.call();
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'share',
          child: ListTile(
            leading: Icon(Icons.share_outlined),
            title: Text('Share'),
            dense: true,
          ),
        ),
        if (post.hidden && isStaff)
          const PopupMenuItem(
            value: 'recover',
            child: ListTile(
              leading: Icon(Icons.restore_rounded),
              title: Text('Recover'),
              dense: true,
            ),
          ),
        if (post.canDelete && !post.hidden)
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline_rounded),
              title: Text('Delete'),
              dense: true,
            ),
          ),
        if (!post.hidden)
          const PopupMenuItem(
            value: 'flag',
            child: ListTile(
              leading: Icon(Icons.flag_outlined),
              title: Text('Flag'),
              dense: true,
            ),
          ),
        if (post.canAcceptAnswer || post.canUnacceptAnswer)
          PopupMenuItem(
            value: 'accept_answer',
            child: ListTile(
              leading: Icon(
                post.acceptedAnswer
                    ? Icons.check_circle_rounded
                    : Icons.check_circle_outline_rounded,
                color: post.acceptedAnswer ? Colors.green : null,
              ),
              title: Text(post.acceptedAnswer ? 'Unaccept Answer' : 'Accept Answer'),
              dense: true,
            ),
          ),
      ],
    );
  }
}
