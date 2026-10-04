import 'package:material_ui/material_ui.dart';

import '../constants/app_strings.dart';
import '../utils/responsive.dart';
import 'app_logo.dart';

/// One item in the main navigation.
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

/// The 5 main sections, in navigation order.
/// Student Voice lives inside Study Zone, so it is not listed here.
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

/// The app's outer frame. Shows [child] (the current page) with:
/// - mobile:  a bottom navigation bar,
/// - tablet:  a compact side rail (icons + labels),
/// - desktop: an extended side rail with the PrepNotes logo.
///
/// It knows nothing about routing: it reports taps via
/// [onDestinationSelected]; the router decides what to show.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return switch (context.screenSize) {
      ScreenSize.mobile => _buildMobile(),
      ScreenSize.tablet => _buildWithRail(extended: false),
      ScreenSize.desktop => _buildWithRail(extended: true),
    };
  }

  Widget _buildMobile() {
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

  Widget _buildWithRail({required bool extended}) {
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: NavigationRail(
              extended: extended,
              minExtendedWidth: 232,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: AppLogo(showName: extended),
              ),
              destinations: [
                for (final d in appDestinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
