import 'package:material_ui/material_ui.dart';

import '../constants/app_strings.dart';
import '../theme/app_theme.dart';

/// PrepNotes brand mark: a claret rounded square with "P", optionally
/// followed by the app name.
class AppLogo extends StatelessWidget {
  const AppLogo({this.showName = true, this.size = 32, super.key});

  final bool showName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final mark = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        AppStrings.appName.substring(0, 1),
        style: text.titleLarge?.copyWith(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );

    if (!showName) {
      return Semantics(label: AppStrings.appName, child: mark);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 10),
        Text(
          AppStrings.appName,
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
