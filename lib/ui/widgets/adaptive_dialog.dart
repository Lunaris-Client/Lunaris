import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

bool _isApplePlatform(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

Widget adaptiveAction({
  required BuildContext context,
  required VoidCallback onPressed,
  required Widget child,
  bool isDestructive = false,
  bool isDefault = false,
}) {
  if (_isApplePlatform(context)) {
    return CupertinoDialogAction(
      onPressed: onPressed,
      isDestructiveAction: isDestructive,
      isDefaultAction: isDefault,
      child: child,
    );
  }
  if (isDefault) {
    return FilledButton(onPressed: onPressed, child: child);
  }
  return TextButton(onPressed: onPressed, child: child);
}

Future<bool?> showAdaptiveConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  String cancelLabel = 'Cancel',
  required String confirmLabel,
  bool isDestructive = false,
}) {
  return showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog.adaptive(
      title: Text(title),
      content: Text(content),
      actions: [
        adaptiveAction(
          context: ctx,
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        adaptiveAction(
          context: ctx,
          onPressed: () => Navigator.pop(ctx, true),
          isDestructive: isDestructive,
          isDefault: true,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
