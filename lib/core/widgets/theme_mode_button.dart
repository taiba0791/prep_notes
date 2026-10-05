import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../constants/app_strings.dart';
import '../theme/theme_mode_controller.dart';

/// 🌙 / ☀️ button that switches between light and dark theme.
class ThemeModeButton extends ConsumerWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeControllerProvider) == ThemeMode.dark;
    return IconButton(
      tooltip: isDark ? AppStrings.switchToLight : AppStrings.switchToDark,
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => ref.read(themeModeControllerProvider.notifier).toggle(),
    );
  }
}
