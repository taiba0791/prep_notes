import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

/// Round profile picture. Shows [initials] on a claret tint when there is no
/// photo, or if the photo fails to load.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    required this.initials,
    this.photoUrl,
    this.radius = 40,
    super.key,
  });

  final String initials;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: scheme.onPrimaryContainer,
          fontSize: radius * 0.7,
        ),
      ),
    );

    final url = photoUrl;
    if (url == null || url.isEmpty) return fallback;

    return CachedNetworkImage(
      imageUrl: url,
      imageBuilder: (context, image) =>
          CircleAvatar(radius: radius, backgroundImage: image),
      placeholder: (context, _) => fallback,
      errorWidget: (context, _, _) => fallback,
    );
  }
}
