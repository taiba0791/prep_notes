import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/config/firebase_config.dart';
import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';

/// Root widget: theme + router.
class PrepNotesApp extends ConsumerWidget {
  const PrepNotesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Light by default; the user can switch (ThemeModeButton).
      themeMode: ref.watch(themeModeControllerProvider),
      routerConfig: ref.watch(appRouterProvider),
      // A corner ribbon so you always know you're on fake emulator data.
      builder: (context, child) => EmulatorConfig.enabled
          ? Banner(
              message: AppStrings.emulatorBanner,
              location: BannerLocation.topEnd,
              color: Theme.of(context).colorScheme.tertiary,
              textStyle: TextStyle(
                color: Theme.of(context).colorScheme.onTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
              child: child!,
            )
          : child!,
    );
  }
}
