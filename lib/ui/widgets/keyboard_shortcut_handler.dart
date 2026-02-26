import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyboardShortcutHandler extends StatelessWidget {
  final Widget child;
  final VoidCallback? onNextItem;
  final VoidCallback? onPreviousItem;
  final VoidCallback? onOpenItem;
  final VoidCallback? onBack;
  final VoidCallback? onRefresh;
  final VoidCallback? onSearch;
  final VoidCallback? onCompose;

  const KeyboardShortcutHandler({
    super.key,
    required this.child,
    this.onNextItem,
    this.onPreviousItem,
    this.onOpenItem,
    this.onBack,
    this.onRefresh,
    this.onSearch,
    this.onCompose,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.keyJ): const _Intent('next'),
        const SingleActivator(LogicalKeyboardKey.keyK): const _Intent('prev'),
        const SingleActivator(LogicalKeyboardKey.enter): const _Intent('open'),
        const SingleActivator(LogicalKeyboardKey.escape): const _Intent('back'),
        const SingleActivator(LogicalKeyboardKey.keyR): const _Intent('refresh'),
        const SingleActivator(LogicalKeyboardKey.slash): const _Intent('search'),
        const SingleActivator(LogicalKeyboardKey.keyN): const _Intent('compose'),
      },
      child: Actions(
        actions: {
          _Intent: CallbackAction<_Intent>(onInvoke: (intent) {
            switch (intent.action) {
              case 'next':
                onNextItem?.call();
              case 'prev':
                onPreviousItem?.call();
              case 'open':
                onOpenItem?.call();
              case 'back':
                onBack?.call();
              case 'refresh':
                onRefresh?.call();
              case 'search':
                onSearch?.call();
              case 'compose':
                onCompose?.call();
            }
            return null;
          }),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

class _Intent extends Intent {
  final String action;
  const _Intent(this.action);
}
