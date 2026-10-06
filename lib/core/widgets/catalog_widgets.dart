import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models/note.dart';
import '../../data/models/university.dart';
import '../constants/app_strings.dart';
import '../router/route_paths.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../utils/responsive.dart';
import 'note_cover.dart';

/// Centres page content at the design's max width (1160 px) with page padding.
class PageContainer extends StatelessWidget {
  const PageContainer({required this.child, this.vertical = 0, super.key});

  final Widget child;
  final double vertical;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Breakpoints.maxContentWidth),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.pagePadding,
          vertical: vertical,
        ),
        child: child,
      ),
    ),
  );
}

/// Serif heading with one claret italic word: "Browse by *university*".
class AccentHeading extends StatelessWidget {
  const AccentHeading({
    required this.start,
    required this.accent,
    this.end = '',
    this.style,
    super.key,
  });

  final String start;
  final String accent;
  final String end;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: start,
        children: [
          TextSpan(
            text: accent,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: context.appColors.highlight,
            ),
          ),
          TextSpan(text: end),
        ],
      ),
      style: style ?? Theme.of(context).textTheme.headlineMedium,
    );
  }
}

/// Heading row with an optional link on the right ("See all universities").
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.heading,
    this.linkLabel,
    this.onLink,
    super.key,
  });

  final Widget heading;
  final String? linkLabel;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 16,
      runSpacing: 8,
      children: [
        heading,
        if (linkLabel != null)
          TextButton(onPressed: onLink, child: Text(linkLabel!)),
      ],
    ),
  );
}

/// A grid that picks its column count from the screen size
/// (design: 1 on phones, 2 on tablets, [desktopColumns] on desktop).
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    required this.children,
    this.desktopColumns = 4,
    this.tabletColumns = 2,
    this.mobileColumns = 1,
    this.spacing = 20,
    super.key,
  });

  final List<Widget> children;
  final int desktopColumns;
  final int tabletColumns;
  final int mobileColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final columns = context.responsive(
      mobile: mobileColumns,
      tablet: tabletColumns,
      desktop: desktopColumns,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final c in children) SizedBox(width: width, child: c),
          ],
        );
      },
    );
  }
}

/// "₹149" in serif, or "Free".
class PriceTag extends StatelessWidget {
  const PriceTag({
    required this.price,
    required this.isFree,
    this.style,
    super.key,
  });

  final int price;
  final bool isFree;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
    isFree ? AppStrings.free : Money.format(price),
    style:
        style ??
        Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w600),
  );
}

/// Small sand pill with teal text ("120 pages").
class InfoPill extends StatelessWidget {
  const InfoPill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.cream,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.secondary, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// The design's note card: cover, "MU · Sem 3", title, price + pages.
class NoteCard extends StatelessWidget {
  const NoteCard({required this.note, super.key});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final context0 = [
      if (note.universityName.isNotEmpty) note.universityName,
      if (note.semesterNumber > 0) 'Sem ${note.semesterNumber}',
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(RoutePaths.note(note.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 5 / 3,
              child: NoteCover(
                title: note.title,
                thumbnailUrl: note.thumbnailUrl,
                borderRadius: 0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (context0.isNotEmpty)
                    Text(
                      context0,
                      style: text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    note.title,
                    style: text.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      PriceTag(price: note.price, isFree: note.isFree),
                      const Spacer(),
                      if (note.pageCount > 0)
                        InfoPill(AppStrings.pages(note.pageCount)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Design's university card: sand circle with short name, name, details.
class UniversityCard extends StatelessWidget {
  const UniversityCard({required this.university, super.key});

  final University university;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final short = university.shortName.isNotEmpty
        ? university.shortName
        : university.name.characters.take(2).toString().toUpperCase();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        onTap: () => context.go(RoutePaths.university(university.id)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: context.appColors.cream,
                foregroundImage: university.logoUrl == null
                    ? null
                    : NetworkImage(university.logoUrl!),
                onForegroundImageError: university.logoUrl == null
                    ? null
                    : (_, _) {},
                child: Text(
                  short.characters.take(4).toString(),
                  style: text.labelLarge?.copyWith(color: scheme.secondary),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                university.name,
                style: text.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (university.city != null && university.city!.isNotEmpty)
                Text(university.city!, style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Notes / Mumbai University / Semester 3" — each part (except the last)
/// is a link.
class Breadcrumbs extends StatelessWidget {
  const Breadcrumbs({required this.items, super.key});

  /// (label, path) — path null for the current page.
  final List<(String, String?)> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Text('  /  ', style: text),
            if (items[i].$2 == null)
              Text(
                items[i].$1,
                style: text?.copyWith(fontWeight: FontWeight.w600),
              )
            else
              InkWell(
                onTap: () => context.go(items[i].$2!),
                child: Text(
                  items[i].$1,
                  style: text?.copyWith(color: context.appColors.link),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Grey placeholder cards while notes load.
class NoteGridSkeleton extends StatelessWidget {
  const NoteGridSkeleton({this.count = 4, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return Semantics(
      label: 'Loading',
      child: ResponsiveGrid(
        children: [
          for (var i = 0; i < count; i++)
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 5 / 3,
                    child: ColoredBox(color: color),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(120, 10),
                        const SizedBox(height: 10),
                        bar(200, 14),
                        const SizedBox(height: 14),
                        bar(60, 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Dark footer from the design: logo + tagline, Explore, Company (legal).
class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = scheme.onInverseSurface;
    final muted = fg.withValues(alpha: 0.7);

    Widget link(String label, String path) => InkWell(
      onTap: () => context.go(path),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(label, style: text.bodyMedium?.copyWith(color: muted)),
      ),
    );

    Widget column(String title, List<Widget> links) => SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.labelLarge?.copyWith(color: fg)),
          const SizedBox(height: 8),
          ...links,
        ],
      ),
    );

    return ColoredBox(
      color: scheme.inverseSurface,
      child: PageContainer(
        vertical: 40,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 32,
              runSpacing: 24,
              children: [
                SizedBox(
                  width: 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.appName,
                        style: text.titleLarge?.copyWith(color: fg),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.footerTagline,
                        style: text.bodyMedium?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                column(AppStrings.footerExplore, [
                  link(AppStrings.navNotes, RoutePaths.notes),
                  link(AppStrings.navStudyZone, RoutePaths.studyZone),
                  link(AppStrings.navResourceRoom, RoutePaths.resources),
                  link(AppStrings.navStudentVoice, RoutePaths.studentVoice),
                ]),
                column(AppStrings.footerCompany, [
                  link(AppStrings.pageAbout, RoutePaths.about),
                  link(AppStrings.pageContact, RoutePaths.contact),
                  link(AppStrings.pagePrivacy, RoutePaths.privacy),
                  link(AppStrings.pageTerms, RoutePaths.terms),
                  link(AppStrings.pageRefundPolicy, RoutePaths.refundPolicy),
                ]),
              ],
            ),
            Divider(height: 48, color: fg.withValues(alpha: 0.2)),
            Text(
              AppStrings.copyright(DateTime.now().year),
              style: text.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
