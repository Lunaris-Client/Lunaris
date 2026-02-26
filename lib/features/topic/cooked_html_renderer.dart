import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

String _resolveUrl(String serverUrl, String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (url.startsWith('//')) return 'https:$url';
  if (url.startsWith('/')) return '$serverUrl$url';
  return url;
}

class CookedHtmlRenderer extends StatelessWidget {
  final String html;
  final String serverUrl;
  final ValueChanged<String>? onMentionTap;
  final ValueChanged<String>? onImageTap;

  const CookedHtmlRenderer({
    super.key,
    required this.html,
    required this.serverUrl,
    this.onMentionTap,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return HtmlWidget(
      html,
      customStylesBuilder: (element) => _buildCustomStyles(element, theme),
      customWidgetBuilder:
          (element) => _buildCustomWidget(element, theme, context),
      onTapUrl: (url) => _handleUrlTap(url),
      onLoadingBuilder:
          (_, __, ___) => const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      onTapImage: (imageMetadata) {
        final src = imageMetadata.sources.firstOrNull?.url;
        if (src != null) {
          onImageTap?.call(_resolveUrl(serverUrl, src));
        }
      },
      textStyle: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
      factoryBuilder:
          () => _DiscourseWidgetFactory(serverUrl: serverUrl, theme: theme),
    );
  }

  Map<String, String>? _buildCustomStyles(dynamic element, ThemeData theme) {
    final localName = element.localName as String?;
    final classes = element.classes as Iterable<String>? ?? [];

    if (localName == 'blockquote') {
      return {
        'border-left': '3px solid ${_colorToCss(theme.colorScheme.primary)}',
        'padding-left': '12px',
        'margin': '8px 0',
      };
    }

    if (localName == 'code' && element.parent?.localName != 'pre') {
      return {
        'background-color': _colorToCss(
          theme.colorScheme.surfaceContainerHighest,
        ),
        'padding': '2px 4px',
        'border-radius': '4px',
      };
    }

    if (localName == 'pre') {
      return {
        'background-color': _colorToCss(
          theme.colorScheme.surfaceContainerHighest,
        ),
        'padding': '12px',
        'border-radius': '8px',
        'margin': '8px 0',
        'overflow': 'auto',
      };
    }

    if (localName == 'aside' && classes.contains('quote')) {
      return {
        'background-color': _colorToCss(theme.colorScheme.surfaceContainerLow),
        'border-left': '3px solid ${_colorToCss(theme.colorScheme.primary)}',
        'border-radius': '4px',
        'padding': '8px 12px',
        'margin': '8px 0',
      };
    }

    if (localName == 'aside' && classes.contains('onebox')) {
      return {
        'background-color': _colorToCss(theme.colorScheme.surfaceContainerLow),
        'border': '1px solid ${_colorToCss(theme.colorScheme.outlineVariant)}',
        'border-radius': '8px',
        'padding': '12px',
        'margin': '8px 0',
      };
    }

    if (localName == 'a' && classes.contains('mention')) {
      return {
        'color': _colorToCss(theme.colorScheme.primary),
        'font-weight': '600',
      };
    }

    return null;
  }

  Widget? _buildCustomWidget(
    dynamic element,
    ThemeData theme,
    BuildContext context,
  ) {
    final localName = element.localName as String?;
    final classes = element.classes as Iterable<String>? ?? [];

    if (localName == 'div' && classes.contains('lightbox-wrapper')) {
      final img = element.querySelector('img');
      if (img != null) {
        final src = img.attributes['src'];
        if (src != null) {
          final resolvedSrc = _resolveUrl(serverUrl, src);
          return _LightboxImage(
            imageUrl: resolvedSrc,
            onTap: () => onImageTap?.call(resolvedSrc),
          );
        }
      }
    }

    return null;
  }

  bool _handleUrlTap(String url) {
    if (url.startsWith('/u/') || url.startsWith('/users/')) {
      final username = url.split('/').last;
      onMentionTap?.call(username);
      return true;
    }

    final resolved = _resolveUrl(serverUrl, url);
    launchUrl(Uri.parse(resolved), mode: LaunchMode.externalApplication);
    return true;
  }

  String _colorToCss(Color color) {
    final r = color.r * 255;
    final g = color.g * 255;
    final b = color.b * 255;
    final a = color.a;
    return 'rgba(${r.round()}, ${g.round()}, ${b.round()}, ${a.toStringAsFixed(2)})';
  }
}

class _DiscourseWidgetFactory extends WidgetFactory {
  final String serverUrl;
  final ThemeData theme;

  _DiscourseWidgetFactory({required this.serverUrl, required this.theme});

  @override
  Widget? buildImageWidget(BuildTree meta, ImageSource src) {
    final url = _resolveUrl(serverUrl, src.url);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder:
            (_, __) => Container(
              height: 150,
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        errorWidget:
            (_, __, ___) => Container(
              height: 80,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
      ),
    );
  }
}

class _LightboxImage extends StatelessWidget {
  final String imageUrl;
  final VoidCallback? onTap;

  const _LightboxImage({required this.imageUrl, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder:
                (_, __) => Container(
                  height: 200,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            errorWidget:
                (_, __, ___) => Container(
                  height: 100,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
