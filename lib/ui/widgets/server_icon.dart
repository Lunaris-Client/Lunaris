import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ServerIcon extends StatelessWidget {
  final String? logoUrl;
  final String? faviconUrl;
  final double size;

  const ServerIcon({
    super.key,
    this.logoUrl,
    this.faviconUrl,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = logoUrl ?? faviconUrl;
    final iconSize = size * 0.5;
    final radius = size * 0.25;

    if (imageUrl == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(
          Icons.forum_rounded,
          size: iconSize,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorWidget: (_, __, ___) => Icon(
            Icons.forum_rounded,
            size: iconSize,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
