import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lunaris/core/models/server_account.dart';
import 'package:lunaris/core/utils/color_utils.dart';

class SidebarNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;
  final ServerAccount? activeServer;
  final int notificationBadgeCount;

  const SidebarNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.extended = false,
    this.activeServer,
    this.notificationBadgeCount = 0,
  });

  static const _destinations = [
    (Icons.forum_outlined, Icons.forum_rounded, 'Feed'),
    (Icons.category_outlined, Icons.category_rounded, 'Categories'),
    (
      Icons.notifications_outlined,
      Icons.notifications_rounded,
      'Notifications',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (!extended) return _buildRail(context);
    return _buildExpanded(context);
  }

  Widget _buildRail(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelType: NavigationRailLabelType.selected,
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => Scaffold.of(context).openDrawer(),
        tooltip: 'Servers',
      ),
      destinations: [
        for (var i = 0; i < _destinations.length; i++)
          NavigationRailDestination(
            icon: _badgedIcon(_destinations[i].$1, i == 2),
            selectedIcon: _badgedIcon(_destinations[i].$2, i == 2),
            label: Text(_destinations[i].$3),
          ),
      ],
    );
  }

  Widget _badgedIcon(IconData iconData, bool showBadge) {
    final icon = Icon(iconData);
    if (!showBadge || notificationBadgeCount == 0) return icon;
    return Badge.count(count: notificationBadgeCount, child: icon);
  }

  Widget _buildExpanded(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Column(
        children: [
          _SidebarHeader(
            activeServer: activeServer,
            onMenuTap: () => Scaffold.of(context).openDrawer(),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (var i = 0; i < _destinations.length; i++)
                  _NavItem(
                    icon: _destinations[i].$1,
                    selectedIcon: _destinations[i].$2,
                    label: _destinations[i].$3,
                    selected: selectedIndex == i,
                    onTap: () => onDestinationSelected(i),
                    badgeCount: i == 2 ? notificationBadgeCount : 0,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  final ServerAccount? activeServer;
  final VoidCallback onMenuTap;

  const _SidebarHeader({required this.activeServer, required this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final server = activeServer;

    if (server == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
        child: Row(
          children: [
            Icon(
              Icons.dark_mode_rounded,
              size: 28,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Lunaris',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: onMenuTap,
              tooltip: 'Servers',
            ),
          ],
        ),
      );
    }

    final avatarUrl =
        server.avatarTemplate != null
            ? resolveAvatarUrl(
              server.serverUrl,
              server.avatarTemplate!,
              size: 80,
            )
            : null;

    return InkWell(
      onTap: onMenuTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
        child: Row(
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
                  Icons.person_rounded,
                  size: 18,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    server.username ?? 'Unknown',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    server.siteName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.unfold_more_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  Widget _buildIcon(ThemeData theme) {
    final color =
        selected
            ? theme.colorScheme.onSecondaryContainer
            : theme.colorScheme.onSurfaceVariant;
    final iconWidget = Icon(
      selected ? selectedIcon : icon,
      size: 24,
      color: color,
    );
    if (badgeCount > 0) {
      return Badge.count(count: badgeCount, child: iconWidget);
    }
    return iconWidget;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color:
            selected
                ? theme.colorScheme.secondaryContainer
                : Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildIcon(theme),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color:
                        selected
                            ? theme.colorScheme.onSecondaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
