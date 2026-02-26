import 'package:flutter/material.dart';

class TimelineScrubber extends StatefulWidget {
  final int currentIndex;
  final int totalPosts;
  final int? lastReadPostNumber;
  final int highestPostNumber;
  final ValueChanged<int> onScrub;

  const TimelineScrubber({
    super.key,
    required this.currentIndex,
    required this.totalPosts,
    this.lastReadPostNumber,
    required this.highestPostNumber,
    required this.onScrub,
  });

  @override
  State<TimelineScrubber> createState() => _TimelineScrubberState();
}

class _TimelineScrubberState extends State<TimelineScrubber> {
  bool _dragging = false;
  double? _dragFraction;

  double get _fraction {
    if (widget.totalPosts <= 1) return 0;
    return widget.currentIndex / (widget.totalPosts - 1);
  }

  double get _displayFraction => _dragFraction ?? _fraction;

  int get _displayPostNumber {
    if (widget.totalPosts <= 1) return 1;
    return (_displayFraction * (widget.totalPosts - 1)).round() + 1;
  }

  double? get _unreadFraction {
    final lastRead = widget.lastReadPostNumber;
    if (lastRead == null || lastRead >= widget.highestPostNumber) return null;
    if (widget.totalPosts <= 1) return null;
    return (lastRead - 1) / (widget.totalPosts - 1);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.totalPosts <= 1) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: 44,
        child: Column(
          children: [
            AnimatedOpacity(
              opacity: _dragging ? 1.0 : 0.8,
              duration: const Duration(milliseconds: 150),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$_displayPostNumber',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(child: _buildTrack(theme)),
            const SizedBox(height: 4),
            Text(
              '${widget.totalPosts}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrack(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackHeight = constraints.maxHeight;
        final thumbY = _displayFraction * (trackHeight - 24);
        final unread = _unreadFraction;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (_) => setState(() => _dragging = true),
          onVerticalDragUpdate: (details) {
            final fraction = (details.localPosition.dy / trackHeight).clamp(
              0.0,
              1.0,
            );
            setState(() => _dragFraction = fraction);
          },
          onVerticalDragEnd: (_) => _finishDrag(),
          onVerticalDragCancel: () => _finishDrag(),
          onTapUp: (details) {
            final fraction = (details.localPosition.dy / trackHeight).clamp(
              0.0,
              1.0,
            );
            final index = (fraction * (widget.totalPosts - 1)).round().clamp(
              0,
              widget.totalPosts - 1,
            );
            widget.onScrub(index);
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 18,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (unread != null)
                Positioned(
                  left: 14,
                  top: unread * (trackHeight - 2),
                  child: Container(
                    width: 12,
                    height: 2,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              Positioned(
                left: 12,
                top: thumbY,
                child: Container(
                  width: 16,
                  height: 24,
                  decoration: BoxDecoration(
                    color:
                        _dragging
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Container(
                      width: 8,
                      height: 2,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onPrimary.withValues(
                          alpha: 0.6,
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _finishDrag() {
    if (_dragFraction != null) {
      final index = (_dragFraction! * (widget.totalPosts - 1)).round().clamp(
        0,
        widget.totalPosts - 1,
      );
      widget.onScrub(index);
    }
    setState(() {
      _dragging = false;
      _dragFraction = null;
    });
  }
}
