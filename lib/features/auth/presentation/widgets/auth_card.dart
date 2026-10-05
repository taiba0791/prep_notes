import 'package:material_ui/material_ui.dart';

import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_logo.dart';

/// Shared layout for login / register / forgot-password:
/// - mobile: full-width form on the page background,
/// - tablet / desktop: a centred card (max 440 px wide) on a cream page.
class AuthCard extends StatelessWidget {
  const AuthCard({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  static const double maxWidth = 440;

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isMobile = context.isMobile;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: AppLogo()),
        const SizedBox(height: 24),
        Text(title, style: text.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(subtitle, style: text.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        child,
      ],
    );

    return Scaffold(
      backgroundColor: isMobile
          ? scheme.surface
          : scheme.surfaceContainerHighest,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.pagePadding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxWidth),
              child: isMobile
                  ? content
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: content,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
