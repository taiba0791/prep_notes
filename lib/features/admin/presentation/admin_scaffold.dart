import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/theme_mode_button.dart';

/// One admin section in the side menu.
class AdminSection {
  const AdminSection(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}

const adminSections = [
  AdminSection(
    AppStrings.adminDashboard,
    Icons.dashboard_outlined,
    RoutePaths.admin,
  ),
  AdminSection(
    AppStrings.adminUniversities,
    Icons.account_balance_outlined,
    RoutePaths.adminUniversities,
  ),
  AdminSection(
    AppStrings.adminSemesters,
    Icons.calendar_view_week_outlined,
    RoutePaths.adminSemesters,
  ),
  AdminSection(
    AppStrings.adminSubjects,
    Icons.class_outlined,
    RoutePaths.adminSubjects,
  ),
  AdminSection(
    AppStrings.adminModules,
    Icons.view_module_outlined,
    RoutePaths.adminModules,
  ),
  AdminSection(
    AppStrings.adminNotes,
    Icons.description_outlined,
    RoutePaths.adminNotes,
  ),
  AdminSection(
    AppStrings.adminUsers,
    Icons.people_outline,
    RoutePaths.adminUsers,
  ),
  AdminSection(
    AppStrings.adminOrders,
    Icons.receipt_long_outlined,
    RoutePaths.adminOrders,
  ),
  AdminSection(
    AppStrings.adminResources,
    Icons.folder_outlined,
    RoutePaths.adminResources,
  ),
  AdminSection(
    AppStrings.adminStudentVoice,
    Icons.forum_outlined,
    RoutePaths.adminStudentVoice,
  ),
];

/// Which section a path belongs to (longest matching prefix).
AdminSection sectionFor(String path) {
  AdminSection best = adminSections.first;
  for (final s in adminSections.skip(1)) {
    if (path == s.path || path.startsWith('${s.path}/')) best = s;
  }
  return best;
}

/// Admin frame (design: dark ink side menu, claret active item).
/// Phones get a horizontally scrolling row of sections instead.
class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    required this.currentPath,
    required this.child,
    super.key,
  });

  final String currentPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final current = sectionFor(currentPath);

    if (context.isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.adminTitle),
          actions: [
            const ThemeModeButton(),
            IconButton(
              tooltip: AppStrings.adminBackToSite,
              icon: const Icon(Icons.storefront_outlined),
              onPressed: () => context.go(RoutePaths.home),
            ),
          ],
        ),
        body: Column(
          children: [
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  for (final s in adminSections)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s.label),
                        selected: s == current,
                        onSelected: (_) => context.go(s.path),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _SideMenu(current: current),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({required this.current});

  final AdminSection current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = scheme.onInverseSurface;

    Widget item(AdminSection s) {
      final selected = s == current;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => context.go(s.path),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    s.icon,
                    size: 20,
                    color: selected ? scheme.onPrimary : fg,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.label,
                      style: text.bodyMedium?.copyWith(
                        color: selected ? scheme.onPrimary : fg,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      // Scrolls on short screens (10 sections + header + back link).
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.adminTitle,
                      style: text.titleLarge?.copyWith(color: fg),
                    ),
                  ),
                  IconTheme(
                    data: IconThemeData(color: fg),
                    child: const ThemeModeButton(),
                  ),
                ],
              ),
            ),
            for (final s in adminSections) item(s),
            Divider(color: fg.withValues(alpha: 0.2)),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: fg,
                alignment: Alignment.centerLeft,
              ),
              onPressed: () => context.go(RoutePaths.home),
              icon: const Icon(Icons.storefront_outlined, size: 20),
              label: const Text(AppStrings.adminBackToSite),
            ),
          ],
        ),
      ),
    );
  }
}
