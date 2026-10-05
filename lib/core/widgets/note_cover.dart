import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

/// A note's cover: its thumbnail, or (design fallback) a coloured block —
/// claret / teal / ink / sand — picked from the title so it stays stable.
class NoteCover extends StatelessWidget {
  const NoteCover({
    required this.title,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.borderRadius = 12,
    super.key,
  });

  final String title;
  final String? thumbnailUrl;
  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palettes = [
      (scheme.primary, scheme.onPrimary),
      (scheme.secondary, scheme.onSecondary),
      (scheme.inverseSurface, scheme.onInverseSurface),
      (scheme.surfaceContainerHighest, scheme.primary),
    ];
    final (bg, fg) = palettes[title.hashCode.abs() % palettes.length];

    final placeholder = ColoredBox(
      color: bg,
      child: Center(child: Icon(Icons.description_outlined, color: fg)),
    );

    final url = thumbnailUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: url == null || url.isEmpty
            ? placeholder
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => placeholder,
                errorWidget: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}
