import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/providers/notification_settings_provider.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/core/services/local_notification_service.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(activeServerProvider);
    if (server == null) {
      return const Scaffold(body: Center(child: Text('No active server')));
    }

    final settings = ref.watch(notificationSettingsProvider(server.serverUrl));
    final notifier = ref.read(
      notificationSettingsProvider(server.serverUrl).notifier,
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(
        children: [
          const _SectionHeader(title: 'General'),
          SwitchListTile(
            title: const Text('Notifications'),
            subtitle: Text('Enable notifications for ${server.siteName}'),
            value: settings.enabled,
            onChanged: (v) => notifier.update(settings.copyWith(enabled: v)),
          ),
          SwitchListTile(
            title: const Text('In-App Toasts'),
            subtitle: const Text('Show floating alerts while using the app'),
            value: settings.showInAppToasts,
            onChanged:
                settings.enabled
                    ? (v) =>
                        notifier.update(settings.copyWith(showInAppToasts: v))
                    : null,
          ),
          SwitchListTile(
            title: const Text('System Notifications'),
            subtitle: const Text(
              'Show notifications in the system notification center',
            ),
            value: settings.showSystemNotifications,
            onChanged:
                settings.enabled
                    ? (v) async {
                      if (v) {
                        final granted =
                            await LocalNotificationService()
                                .requestPermissions();
                        if (!granted) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Notification permission denied'),
                              ),
                            );
                          }
                          return;
                        }
                      }
                      notifier.update(
                        settings.copyWith(showSystemNotifications: v),
                      );
                    }
                    : null,
          ),
          const Divider(),
          const _SectionHeader(title: 'Quiet Hours'),
          SwitchListTile(
            title: const Text('Do Not Disturb'),
            subtitle: const Text('Silence notifications during set hours'),
            value: settings.quietHoursEnabled,
            onChanged:
                settings.enabled
                    ? (v) =>
                        notifier.update(settings.copyWith(quietHoursEnabled: v))
                    : null,
          ),
          if (settings.quietHoursEnabled && settings.enabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _TimePicker(
                      label: 'From',
                      hour: settings.quietHoursStart,
                      onChanged:
                          (h) => notifier.update(
                            settings.copyWith(quietHoursStart: h),
                          ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _TimePicker(
                      label: 'Until',
                      hour: settings.quietHoursEnd,
                      onChanged:
                          (h) => notifier.update(
                            settings.copyWith(quietHoursEnd: h),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          const _SectionHeader(title: 'Notification Types'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Choose which types of notifications trigger alerts',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 4),
          _TypeToggle(
            icon: Icons.reply_rounded,
            title: 'Replies & Posts',
            value: settings.filterReplies,
            enabled: settings.enabled,
            onChanged:
                (v) => notifier.update(settings.copyWith(filterReplies: v)),
          ),
          _TypeToggle(
            icon: Icons.alternate_email_rounded,
            title: 'Mentions & Quotes',
            value: settings.filterMentions,
            enabled: settings.enabled,
            onChanged:
                (v) => notifier.update(settings.copyWith(filterMentions: v)),
          ),
          _TypeToggle(
            icon: Icons.favorite_rounded,
            title: 'Likes',
            value: settings.filterLikes,
            enabled: settings.enabled,
            onChanged:
                (v) => notifier.update(settings.copyWith(filterLikes: v)),
          ),
          _TypeToggle(
            icon: Icons.mail_rounded,
            title: 'Private Messages',
            value: settings.filterMessages,
            enabled: settings.enabled,
            onChanged:
                (v) => notifier.update(settings.copyWith(filterMessages: v)),
          ),
          _TypeToggle(
            icon: Icons.more_horiz_rounded,
            title: 'Other',
            value: settings.filterOther,
            enabled: settings.enabled,
            onChanged:
                (v) => notifier.update(settings.copyWith(filterOther: v)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TimePicker extends StatelessWidget {
  final String label;
  final int hour;
  final ValueChanged<int> onChanged;

  const _TimePicker({
    required this.label,
    required this.hour,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = TimeOfDay(hour: hour, minute: 0);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) onChanged(picked.hour);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        child: Text(time.format(context), style: theme.textTheme.bodyLarge),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _TypeToggle({
    required this.icon,
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}
