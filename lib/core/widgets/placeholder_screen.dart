import 'package:material_ui/material_ui.dart';

import '../constants/app_strings.dart';
import '../utils/responsive.dart';
import 'theme_mode_button.dart';

/// Temporary page used for every route until its real screen is built.
/// Shows the page title, any URL parameters, and optional extra [actions].
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.title,
    this.params = const {},
    this.actions = const [],
    super.key,
  });

  final String title;
  final Map<String, String> params;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        // On tablet/desktop the switch lives in the side rail instead.
        actions: [if (context.isMobile) const ThemeModeButton()],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: scheme.secondaryContainer,
                child: Icon(
                  Icons.construction,
                  size: 32,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: text.headlineSmall),
              const SizedBox(height: 8),
              Text(AppStrings.comingSoon, style: text.bodyLarge),
              for (final entry in params.entries) ...[
                const SizedBox(height: 8),
                Text('${entry.key}: ${entry.value}', style: text.labelLarge),
              ],
              for (final action in actions) ...[
                const SizedBox(height: 12),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
