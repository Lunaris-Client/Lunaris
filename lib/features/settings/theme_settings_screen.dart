import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/models/theme_settings.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/core/providers/theme_settings_provider.dart';
import 'package:lunaris/ui/theme/lunaris_theme.dart';
import 'package:lunaris/ui/widgets/section_header.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeSettingsProvider);
    final notifier = ref.read(themeSettingsProvider.notifier);
    final seedColor = ref.watch(effectiveSeedColorProvider);
    final theme = Theme.of(context);

    final server = ref.watch(activeServerProvider);
    final hasServerColors = _hasServerColorScheme(ref, server?.serverUrl);

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        children: [
          const SectionHeader(title: 'Theme Mode'),
          _ThemeModeOption(
            title: 'System',
            subtitle: 'Follow device settings',
            icon: Icons.brightness_auto_rounded,
            selected: settings.themeMode == ThemeMode.system,
            onTap: () => notifier.setThemeMode(ThemeMode.system),
          ),
          _ThemeModeOption(
            title: 'Light',
            subtitle: 'Always use light theme',
            icon: Icons.light_mode_rounded,
            selected: settings.themeMode == ThemeMode.light,
            onTap: () => notifier.setThemeMode(ThemeMode.light),
          ),
          _ThemeModeOption(
            title: 'Dark',
            subtitle: 'Always use dark theme',
            icon: Icons.dark_mode_rounded,
            selected: settings.themeMode == ThemeMode.dark,
            onTap: () => notifier.setThemeMode(ThemeMode.dark),
          ),
          const Divider(),
          const SectionHeader(title: 'Accent Color'),
          if (hasServerColors)
            SwitchListTile.adaptive(
              title: const Text('Use Server Colors'),
              subtitle: Text(
                server?.siteName != null
                    ? 'Apply color scheme from ${server!.siteName}'
                    : 'Apply the active server\'s color scheme',
              ),
              value: settings.useServerColors,
              onChanged: (v) => notifier.setUseServerColors(v),
            ),
          if (!settings.useServerColors || !hasServerColors) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Choose an accent color',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _ColorPalette(
              selectedColor: seedColor,
              onColorSelected: (color) {
                final hex = (color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
                notifier.setCustomColor(hex);
              },
              onResetToDefault: () => notifier.setCustomColor(null),
            ),
          ],
          const Divider(),
          const SectionHeader(title: 'Preview'),
          _ThemePreview(seedColor: seedColor),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  bool _hasServerColorScheme(WidgetRef ref, String? serverUrl) {
    if (serverUrl == null) return false;
    final siteAsync = ref.watch(siteDataProvider(serverUrl));
    final siteData = siteAsync.valueOrNull;
    if (siteData == null) return false;
    return siteData.defaultLightColors != null || siteData.defaultDarkColors != null;
  }
}

class _ThemeModeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeModeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
          : const Icon(Icons.circle_outlined),
      onTap: onTap,
    );
  }
}

class _ColorPalette extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback onResetToDefault;

  const _ColorPalette({
    required this.selectedColor,
    required this.onColorSelected,
    required this.onResetToDefault,
  });

  static const _presetColors = [
    ThemeSettings.defaultSeedColor,
    Color(0xFF6750A4),
    Color(0xFF009688),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFFF44336),
    Color(0xFFE91E63),
    Color(0xFF795548),
    Color(0xFF607D8B),
    Color(0xFF00BCD4),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in _presetColors)
                _ColorDot(
                  color: color,
                  selected: _isSameBaseColor(selectedColor, color),
                  onTap: () => onColorSelected(color),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onResetToDefault,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reset to default'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameBaseColor(Color a, Color b) {
    return (a.toARGB32() & 0x00FFFFFF) == (b.toARGB32() & 0x00FFFFFF);
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 3,
                )
              : null,
          boxShadow: selected
              ? [BoxShadow(color: color.withAlpha(100), blurRadius: 8, spreadRadius: 1)]
              : null,
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  final Color seedColor;
  const _ThemePreview({required this.seedColor});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final previewTheme = brightness == Brightness.dark
        ? LunarisTheme.dark(seedColor: seedColor)
        : LunarisTheme.light(seedColor: seedColor);
    final cs = previewTheme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: cs.primary,
              child: Text(
                'Primary',
                style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: cs.surface,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PreviewChip(label: 'Secondary', color: cs.secondary, onColor: cs.onSecondary),
                  _PreviewChip(label: 'Tertiary', color: cs.tertiary, onColor: cs.onTertiary),
                  _PreviewChip(label: 'Error', color: cs.error, onColor: cs.onError),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color onColor;

  const _PreviewChip({
    required this.label,
    required this.color,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(color: onColor, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}
