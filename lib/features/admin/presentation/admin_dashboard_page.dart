import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/utils/responsive.dart';

/// Admin dashboard. Live stats and charts come in Phase 5; for now: the
/// design's stat cards and quick links into catalog management.
class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stats = [
      AppStrings.adminStatStudents,
      AppStrings.adminStatNotes,
      AppStrings.adminStatPurchases,
      AppStrings.adminStatRevenue,
    ];
    final links = [
      (
        AppStrings.adminUniversities,
        Icons.account_balance_outlined,
        RoutePaths.adminUniversities,
      ),
      (
        AppStrings.adminSubjects,
        Icons.class_outlined,
        RoutePaths.adminSubjects,
      ),
      (
        AppStrings.adminNotes,
        Icons.description_outlined,
        RoutePaths.adminNotes,
      ),
      (AppStrings.newNote, Icons.add_circle_outline, RoutePaths.adminNoteNew),
    ];
    final columns = context.responsive(mobile: 2, tablet: 2, desktop: 4);

    return ListView(
      padding: EdgeInsets.all(context.pagePadding),
      children: [
        Text(AppStrings.adminDashboard, style: text.headlineMedium),
        const SizedBox(height: 4),
        Text(AppStrings.adminDashboardSoon, style: text.bodyMedium),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.2,
          children: [
            for (final label in stats)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label, style: text.bodySmall),
                      Text('—', style: text.headlineMedium),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (label, icon, path) in links)
              OutlinedButton.icon(
                onPressed: () => context.go(path),
                icon: Icon(icon),
                label: Text(label),
              ),
          ],
        ),
      ],
    );
  }
}
