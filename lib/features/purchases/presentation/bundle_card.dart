import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/models/catalog.dart';
import '../../notes/presentation/browse_providers.dart';
import '../data/payment_service.dart';
import 'checkout_screen.dart';
import 'purchases_controllers.dart';

final _day = DateFormat('d MMM yyyy');

/// "Whole semester bundle" offer on a semester page: every note of the
/// semester + the Resource Room for 6 months. Hidden while the semester has
/// no notes.
class SemesterBundleCard extends ConsumerWidget {
  const SemesterBundleCard({required this.semester, super.key});

  final Semester semester;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(semesterNoteCountProvider(semester.id)).value ?? 0;
    if (count == 0) return const SizedBox.shrink();
    final bundle = ref.watch(semesterBundleProvider(semester.id)).value;
    final active = bundle?.isActiveAt(DateTime.now()) ?? false;
    final buyInApp = ref.watch(buyInAppProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final perks = [
      AppStrings.bundleNotes(count),
      AppStrings.bundleLaterNotes,
      AppStrings.bundleRoom,
      AppStrings.bundleSixMonths,
    ];

    final Widget action;
    if (active) {
      action = Row(
        children: [
          Icon(Icons.check_circle, color: context.appColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppStrings.bundleActive(_day.format(bundle!.expiresAt!)),
              style: text.titleSmall,
            ),
          ),
        ],
      );
    } else if (buyInApp) {
      action = FilledButton(
        onPressed: () => context.push(RoutePaths.checkoutBundle(semester.id)),
        child: Text(
          '${bundle == null ? AppStrings.buyBundle : AppStrings.bundleRenew}'
          ' · ${Money.format(semester.effectiveBundlePrice)}',
        ),
      );
    } else {
      action = BuyOnWebsiteButton(
        noteId: '',
        path: RoutePaths.semester(semester.id),
      );
    }

    return Card(
      color: context.appColors.cream,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Flex(
          direction: context.isMobile ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: context.isMobile
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: context.isMobile ? 0 : 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.library_books, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.bundleTitle,
                          style: text.titleLarge,
                        ),
                      ),
                      Text(
                        Money.format(semester.effectiveBundlePrice),
                        style: text.headlineSmall?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final p in perks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check,
                            size: 18,
                            color: context.appColors.success,
                          ),
                          const SizedBox(width: 6),
                          Expanded(child: Text(p, style: text.bodyMedium)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: 20, height: context.isMobile ? 14 : 0),
            Expanded(flex: context.isMobile ? 0 : 2, child: action),
          ],
        ),
      ),
    );
  }
}
