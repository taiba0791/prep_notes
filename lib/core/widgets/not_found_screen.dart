import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../constants/app_strings.dart';
import '../router/route_paths.dart';
import '../utils/responsive.dart';

/// Shown for any URL that doesn't match a route (404).
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '404',
                style: text.displayLarge?.copyWith(color: scheme.primary),
              ),
              const SizedBox(height: 8),
              Text(AppStrings.notFoundTitle, style: text.headlineSmall),
              const SizedBox(height: 8),
              Text(
                AppStrings.notFoundMessage,
                style: text.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(RoutePaths.home),
                child: const Text(AppStrings.goHome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
