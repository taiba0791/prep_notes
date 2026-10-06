import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_links.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/note_cover.dart';
import '../../../core/widgets/state_views.dart';
import '../../notes/presentation/browse_providers.dart';
import '../data/payment_service.dart';
import 'purchases_controllers.dart';

final _day = DateFormat('d MMM yyyy');

/// Opens a page on the website (phones buy there).
class BuyOnWebsiteButton extends StatelessWidget {
  const BuyOnWebsiteButton({required this.noteId, this.path, super.key});

  final String noteId;

  /// A site path to open instead of the note page (e.g. a semester).
  final String? path;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: const Text(AppStrings.buyOnWebsite),
          onPressed: () => launchUrl(
            Uri.parse(
              path == null
                  ? AppLinks.noteOnWebsite(noteId)
                  : '${AppLinks.website}$path',
            ),
            mode: LaunchMode.externalApplication,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.buyOnWebsiteHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// What the checkout card shows, whatever is being bought.
class _Summary {
  const _Summary({
    required this.title,
    required this.subtitle,
    required this.price,
    this.priceSuffix,
    this.thumbnailUrl,
    this.bullets = const [],
    this.alreadyHave = false,
    this.websitePath,
  });

  final String title;
  final String subtitle;
  final int price;
  final String? priceSuffix;
  final String? thumbnailUrl;
  final List<String> bullets;
  final bool alreadyHave;
  final String? websitePath;
}

/// `/checkout/:noteId`, `/checkout/bundle/:semesterId`,
/// `/checkout/room/:planKey` — website payments.
class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({required this.target, super.key});

  final CheckoutTarget target;

  /// Loads the summary for [target]; null = not available.
  AsyncValue<_Summary?> _summary(WidgetRef ref) {
    final now = DateTime.now();
    switch (target.kind) {
      case CheckoutKind.note:
        final note = ref.watch(noteDetailsProvider(target.id));
        final access = ref.watch(noteAccessProvider(target.id));
        return note.whenData(
          (n) => n == null || n.isFree
              ? null
              : _Summary(
                  title: n.title,
                  subtitle: n.subjectName,
                  price: n.price,
                  thumbnailUrl: n.thumbnailUrl,
                  bullets: const [AppStrings.accessSixMonths],
                  alreadyHave: access.value?.canRead ?? false,
                  websitePath: RoutePaths.note(n.id),
                ),
        );
      case CheckoutKind.bundle:
        final sem = ref.watch(semesterByIdProvider(target.id));
        final count = ref.watch(semesterNoteCountProvider(target.id)).value;
        final bundle = ref.watch(semesterBundleProvider(target.id)).value;
        return sem.whenData((s) {
          if (s == null || !s.isActive) return null;
          final uni = ref.watch(universityByIdProvider(s.universityId)).value;
          return _Summary(
            title: AppStrings.semesterBundleName(s.number),
            subtitle: uni?.name ?? '',
            price: s.effectiveBundlePrice,
            bullets: [
              if (count != null) AppStrings.bundleNotes(count),
              AppStrings.bundleLaterNotes,
              AppStrings.bundleRoom,
              AppStrings.bundleSixMonths,
            ],
            alreadyHave: bundle?.isActiveAt(now) ?? false,
            websitePath: RoutePaths.semester(s.id),
          );
        });
      case CheckoutKind.room:
        final plans = ref.watch(roomPlansProvider);
        final sub = ref.watch(roomSubscriptionProvider).value;
        return plans.whenData((all) {
          final plan = all.where((p) => p.key == target.id).firstOrNull;
          if (plan == null) return null;
          return _Summary(
            title: AppStrings.roomTitle,
            subtitle: AppStrings.planName(plan.months),
            price: plan.price,
            priceSuffix: AppStrings.perMonths(plan.months),
            bullets: const [
              AppStrings.roomFeatureLinks,
              AppStrings.roomFeatureFiles,
              AppStrings.roomFeatureInApp,
            ],
            alreadyHave: sub?.renews ?? false,
            websitePath: RoutePaths.resources,
          );
        });
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = _summary(ref);
    final back = switch (target.kind) {
      CheckoutKind.note => RoutePaths.note(target.id),
      CheckoutKind.bundle => RoutePaths.semester(target.id),
      CheckoutKind.room => RoutePaths.resources,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.checkoutTitle),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go(back),
        ),
      ),
      body: summary.when(
        loading: () => const LoadingView(),
        error: (_, _) => ErrorView(
          onRetry: () => ref
            ..invalidate(noteDetailsProvider)
            ..invalidate(semesterByIdProvider)
            ..invalidate(roomPlansProvider),
        ),
        data: (s) => s == null
            ? EmptyView(
                icon: Icons.search_off,
                title: AppStrings.payErrNotAvailable,
                message: '',
                action: FilledButton(
                  onPressed: () => context.go(RoutePaths.notes),
                  child: const Text(AppStrings.browseAllNotes),
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.all(context.pagePadding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _CheckoutCard(target: target, summary: s),
                  ),
                ),
              ),
      ),
    );
  }
}

class _CheckoutCard extends ConsumerWidget {
  const _CheckoutCard({required this.target, required this.summary});

  final CheckoutTarget target;
  final _Summary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(checkoutControllerProvider(target.key));
    final canBuy = ref.watch(buyInAppProvider);
    final s = summary;

    if (state.step == CheckoutStep.success || s.alreadyHave) {
      return _Success(target: target);
    }

    final price = Money.format(s.price);
    final color = scheme.primary.toARGB32() & 0xFFFFFF;
    Future<void> pay() => ref
        .read(checkoutControllerProvider(target.key).notifier)
        .pay(
          description: '${s.title} · ${s.subtitle}',
          themeColor: '#${color.toRadixString(16).padLeft(6, '0')}',
        );

    final busyText = switch (state.step) {
      CheckoutStep.creating => AppStrings.checkoutCreating,
      CheckoutStep.paying => AppStrings.checkoutPaying,
      CheckoutStep.verifying => AppStrings.checkoutVerifying,
      _ => null,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (target.kind == CheckoutKind.note)
                  NoteCover(
                    title: s.title,
                    thumbnailUrl: s.thumbnailUrl,
                    width: 72,
                    height: 72,
                  )
                else
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: context.appColors.cream,
                    child: Icon(
                      target.kind == CheckoutKind.room
                          ? Icons.workspace_premium_outlined
                          : Icons.library_books_outlined,
                      color: scheme.secondary,
                    ),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title, style: text.titleMedium),
                      if (s.subtitle.isNotEmpty)
                        Text(s.subtitle, style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final b in s.bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: context.appColors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(b, style: text.bodyMedium)),
                  ],
                ),
              ),
            const Divider(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(AppStrings.checkoutTotal, style: text.titleMedium),
                const Spacer(),
                Text(price, style: text.headlineSmall),
                if (s.priceSuffix != null) ...[
                  const SizedBox(width: 4),
                  Text(s.priceSuffix!, style: text.bodySmall),
                ],
              ],
            ),
            const SizedBox(height: 20),
            if (state.step == CheckoutStep.failed && state.message != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  state.message!,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (!canBuy)
              BuyOnWebsiteButton(noteId: target.id, path: s.websitePath)
            else
              FilledButton(
                onPressed: state.isBusy ? null : pay,
                child: state.isBusy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        state.step == CheckoutStep.failed
                            ? AppStrings.retry
                            : target.kind == CheckoutKind.room
                            ? '${AppStrings.subscribe} · $price'
                            : AppStrings.payAmount(price),
                      ),
              ),
            if (busyText != null) ...[
              const SizedBox(height: 10),
              Text(
                busyText,
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: scheme.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(AppStrings.securePayment, style: text.bodySmall),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              target.kind == CheckoutKind.room
                  ? AppStrings.checkoutAutoRenewTerms
                  : AppStrings.checkoutTerms,
              style: text.bodySmall,
            ),
            Wrap(
              children: [
                TextButton(
                  onPressed: () => context.push(RoutePaths.terms),
                  child: const Text(AppStrings.pageTerms),
                ),
                TextButton(
                  onPressed: () => context.push(RoutePaths.refundPolicy),
                  child: const Text(AppStrings.pageRefundPolicy),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({required this.target});

  final CheckoutTarget target;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (label, path) = switch (target.kind) {
      CheckoutKind.note => (
        AppStrings.readNow,
        RoutePaths.noteViewer(target.id),
      ),
      CheckoutKind.bundle => (
        AppStrings.browseAllNotes,
        RoutePaths.semester(target.id),
      ),
      CheckoutKind.room => (AppStrings.roomTitle, RoutePaths.resources),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.check_circle,
              size: 56,
              color: context.appColors.success,
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.paymentSuccessTitle,
              textAlign: TextAlign.center,
              style: text.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.paymentSuccessMessage,
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            const SizedBox(height: 22),
            FilledButton(onPressed: () => context.go(path), child: Text(label)),
            if (target.kind == CheckoutKind.bundle) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => context.go(RoutePaths.resources),
                child: const Text(AppStrings.roomTitle),
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.go(RoutePaths.purchases),
              child: const Text(AppStrings.goToPurchases),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Access until 6 Apr 2027" helper used around the app.
String accessUntilText(DateTime? date) => date == null
    ? AppStrings.expired
    : AppStrings.accessUntil(_day.format(date));
