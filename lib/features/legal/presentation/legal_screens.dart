import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/catalog_widgets.dart';
import '../domain/legal_content.dart';

/// A legal / info page: title, "last updated", sections, links, footer.
class LegalScreen extends StatelessWidget {
  const LegalScreen({required this.document, super.key});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: context.isMobile ? AppBar(title: Text(document.title)) : null,
      body: ListView(
        children: [
          PageContainer(
            vertical: context.pagePadding * 1.5,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(document.title, style: text.headlineLarge),
                    const SizedBox(height: 6),
                    Text(
                      AppStrings.lastUpdated(LegalInfo.lastUpdated),
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    Text(document.intro, style: text.bodyLarge),
                    for (final s in document.sections) ...[
                      const SizedBox(height: 28),
                      Text(s.heading, style: text.titleLarge),
                      const SizedBox(height: 8),
                      for (final p in s.paragraphs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SelectableText(p, style: text.bodyLarge),
                        ),
                      for (final b in s.bullets)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 9,
                                  right: 12,
                                ),
                                child: CircleAvatar(
                                  radius: 4,
                                  backgroundColor: scheme.secondary,
                                ),
                              ),
                              Expanded(
                                child: SelectableText(b, style: text.bodyLarge),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 32),
                    const _LegalLinks(),
                  ],
                ),
              ),
            ),
          ),
          const SiteFooter(),
        ],
      ),
    );
  }
}

/// Links between the legal pages (handy for payment-gateway reviewers).
class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, path) in const [
          (AppStrings.pagePrivacy, RoutePaths.privacy),
          (AppStrings.pageTerms, RoutePaths.terms),
          (AppStrings.pageRefundPolicy, RoutePaths.refundPolicy),
          (AppStrings.pageDeliveryPolicy, RoutePaths.deliveryPolicy),
          (AppStrings.pageContact, RoutePaths.contact),
        ])
          ActionChip(label: Text(label), onPressed: () => context.go(path)),
      ],
    );
  }
}

/// Contact page: email (opens the mail app), reply time, and where to send
/// note requests.
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget item(
      IconData icon,
      String title,
      String body, {
      VoidCallback? onTap,
    }) => Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: context.appColors.cream,
          child: Icon(icon, color: scheme.secondary),
        ),
        title: Text(title, style: text.titleMedium),
        subtitle: SelectableText(body, style: text.bodyMedium),
        trailing: onTap == null ? null : const Icon(Icons.open_in_new),
        onTap: onTap,
      ),
    );

    return Scaffold(
      appBar: context.isMobile
          ? AppBar(title: const Text(AppStrings.pageContact))
          : null,
      body: ListView(
        children: [
          PageContainer(
            vertical: context.pagePadding * 1.5,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AccentHeading(
                      start: AppStrings.contactTitleStart,
                      accent: AppStrings.contactTitleAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(AppStrings.contactIntro, style: text.bodyLarge),
                    const SizedBox(height: 24),
                    item(
                      Icons.mail_outline,
                      AppStrings.contactEmailLabel,
                      LegalInfo.email,
                      onTap: () => launchUrl(
                        Uri(scheme: 'mailto', path: LegalInfo.email),
                      ),
                    ),
                    const SizedBox(height: 12),
                    item(
                      Icons.schedule,
                      AppStrings.contactReplyLabel,
                      AppStrings.contactReplyBody(LegalInfo.replyWithin),
                    ),
                    const SizedBox(height: 12),
                    item(
                      Icons.forum_outlined,
                      AppStrings.contactRequestsLabel,
                      AppStrings.contactRequestsBody,
                      onTap: () => context.go(RoutePaths.studentVoice),
                    ),
                    const SizedBox(height: 12),
                    item(
                      Icons.business_outlined,
                      AppStrings.contactOperatorLabel,
                      '${LegalInfo.operatorName}, ${LegalInfo.country}',
                    ),
                    const SizedBox(height: 32),
                    const _LegalLinks(),
                  ],
                ),
              ),
            ),
          ),
          const SiteFooter(),
        ],
      ),
    );
  }
}
