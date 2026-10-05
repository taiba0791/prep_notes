import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/current_user_providers.dart';
import '../constants/app_strings.dart';
import '../router/route_paths.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'app_logo.dart';
import 'theme_mode_button.dart';
import 'user_avatar.dart';

/// One item in the phone's bottom navigation bar.
class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The 5 tab branches, in order (index = branch index in the router).
/// Phones show these in the bottom bar.
const List<AppDestination> appDestinations = [
  AppDestination(
    label: AppStrings.navHome,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  AppDestination(
    label: AppStrings.navNotes,
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
  ),
  AppDestination(
    label: AppStrings.navStudyZone,
    icon: Icons.timer_outlined,
    selectedIcon: Icons.timer,
  ),
  AppDestination(
    label: AppStrings.navResources,
    icon: Icons.folder_outlined,
    selectedIcon: Icons.folder,
  ),
  AppDestination(
    label: AppStrings.navProfile,
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  ),
];

/// Branch indexes (must match the order of branches in app_router.dart).
abstract final class AppBranch {
  static const home = 0;
  static const notes = 1;
  static const studyZone = 2;
  static const resources = 3;
  static const profile = 4;
}

/// The app's outer frame:
/// - phone (<600): bottom navigation bar with the 5 tabs;
/// - tablet / desktop: the design's top navigation bar — logo · Notes ·
///   Study Zone · Resource Room · Student Voice · theme · Log in / Sign up
///   (or the user's avatar).
///
/// It knows nothing about routing: it reports taps through
/// [onDestinationSelected] (switch tab) and [onNavigate] (open a path).
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    this.onNavigate,
    this.currentPath = '',
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<String>? onNavigate;
  final String currentPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: [
            for (final d in appDestinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          _TopNav(
            selectedIndex: selectedIndex,
            currentPath: currentPath,
            onDestinationSelected: onDestinationSelected,
            onNavigate: onNavigate ?? (_) {},
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _TopNav extends ConsumerWidget {
  const _TopNav({
    required this.selectedIndex,
    required this.currentPath,
    required this.onDestinationSelected,
    required this.onNavigate,
  });

  final int selectedIndex;
  final String currentPath;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<String> onNavigate;

  static const double height = 68;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final session = ref.watch(authSessionProvider).value;
    final signedIn = session?.isSignedIn ?? false;
    final onStudentVoice = currentPath.startsWith(RoutePaths.studentVoice);

    final links = <(String, bool, VoidCallback)>[
      (
        AppStrings.navNotes,
        selectedIndex == AppBranch.notes,
        () => onDestinationSelected(AppBranch.notes),
      ),
      (
        AppStrings.navStudyZone,
        selectedIndex == AppBranch.studyZone && !onStudentVoice,
        () => onDestinationSelected(AppBranch.studyZone),
      ),
      (
        AppStrings.navResourceRoom,
        selectedIndex == AppBranch.resources,
        () => onDestinationSelected(AppBranch.resources),
      ),
      (
        AppStrings.navStudentVoice,
        onStudentVoice,
        () => onNavigate(RoutePaths.studentVoice),
      ),
    ];

    final logo = Semantics(
      button: true,
      label: AppStrings.navHome,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        onTap: () => onDestinationSelected(AppBranch.home),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: AppLogo(),
        ),
      ),
    );

    final linkRow = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (label, selected, onTap) in links)
            _NavLink(label: label, selected: selected, onTap: onTap),
        ],
      ),
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ThemeModeButton(),
        const SizedBox(width: 8),
        if (signedIn)
          _AvatarButton(
            selected: selectedIndex == AppBranch.profile,
            onTap: () => onDestinationSelected(AppBranch.profile),
          )
        else ...[
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () => onNavigate(RoutePaths.login),
            child: const Text(AppStrings.loginButton),
          ),
          const SizedBox(width: 10),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () => onNavigate(RoutePaths.register),
            child: const Text(AppStrings.signUpFree),
          ),
        ],
      ],
    );

    // Desktop: one row, as in the design. Tablet: links get their own row
    // underneath so they never slide under the buttons.
    final content = context.isDesktop
        ? SizedBox(
            height: height,
            child: Row(
              children: [
                logo,
                const SizedBox(width: 24),
                Expanded(child: linkRow),
                const SizedBox(width: 8),
                actions,
              ],
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: height - 8,
                child: Row(children: [logo, const Spacer(), actions]),
              ),
              Align(alignment: Alignment.centerLeft, child: linkRow),
              const SizedBox(height: 4),
            ],
          );

    return Material(
      color: scheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Breakpoints.maxContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = context.appColors.link;
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: text.bodyMedium?.copyWith(
              color: selected ? accent : scheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarButton extends ConsumerWidget {
  const _AvatarButton({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: AppStrings.navProfile,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: UserAvatar(
            radius: 18,
            initials: profile?.initials ?? '?',
            photoUrl: profile?.photoUrl,
          ),
        ),
      ),
    );
  }
}
