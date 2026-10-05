import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/theme_mode_button.dart';

/// Shared layout for login / register / forgot-password (design: "Login"):
/// - tablet / desktop: one rounded card split in two — a claret welcome
///   panel on the left, the form on the right (max 960 px);
/// - phone: a short claret header above the full-width form.
class AuthCard extends StatelessWidget {
  const AuthCard({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  static const double maxWidth = 960;

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final form = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: text.headlineMedium),
        const SizedBox(height: 6),
        Text(subtitle, style: text.bodyMedium),
        const SizedBox(height: 24),
        child,
      ],
    );

    if (context.isMobile) {
      return Scaffold(
        body: SafeArea(
          child: ListView(
            children: [
              const _WelcomePanel(compact: true),
              Padding(
                padding: EdgeInsets.all(context.pagePadding),
                child: form,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surfaceContainerHighest,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.pagePadding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxWidth),
              child: Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(child: _WelcomePanel(compact: false)),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(44),
                          child: Center(child: form),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Claret panel: logo, serif headline with a sand italic accent, tagline.
class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final onPanel = scheme.onPrimary;
    final accent = context.appColors.cream;

    final headline = Text.rich(
      TextSpan(
        text: AppStrings.authPanelHeadlineStart,
        children: [
          TextSpan(
            text: AppStrings.authPanelHeadlineAccent,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              // Sand on claret in light mode; in dark mode the cream token is
              // dark, so stay with the text colour.
              color: Theme.of(context).brightness == Brightness.light
                  ? accent
                  : onPanel,
            ),
          ),
          const TextSpan(text: AppStrings.authPanelHeadlineEnd),
        ],
      ),
      style: (compact ? text.headlineSmall : text.headlineMedium)?.copyWith(
        color: onPanel,
      ),
    );

    return ColoredBox(
      color: scheme.primary,
      child: Padding(
        padding: EdgeInsets.all(compact ? 24 : 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Flexible(
                  child: Theme(
                    // White logo mark on claret.
                    data: Theme.of(context).copyWith(
                      colorScheme: scheme.copyWith(
                        primary: onPanel,
                        onPrimary: scheme.primary,
                        onSurface: onPanel,
                      ),
                      textTheme: text.apply(
                        bodyColor: onPanel,
                        displayColor: onPanel,
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AppLogo(),
                    ),
                  ),
                ),
                const Spacer(),
                IconTheme(
                  data: IconThemeData(color: onPanel),
                  child: const ThemeModeButton(),
                ),
              ],
            ),
            SizedBox(height: compact ? 16 : 32),
            headline,
            const SizedBox(height: 12),
            Text(
              AppStrings.authPanelTagline,
              style: text.bodyMedium?.copyWith(
                color: onPanel.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
