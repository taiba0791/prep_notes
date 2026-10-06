import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../../data/models/note.dart';
import '../../notes/presentation/browse_providers.dart';
import '../data/payment_service.dart';
import 'purchases_controllers.dart';

/// Opens this note's page on the website (phones buy there).
class BuyOnWebsiteButton extends StatelessWidget {
  const BuyOnWebsiteButton({required this.noteId, super.key});

  final String noteId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: const Text(AppStrings.buyOnWebsite),
          onPressed: () => launchUrl(
            Uri.parse(AppLinks.noteOnWebsite(noteId)),
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

/// `/checkout/:noteId` — pay for one note (website only).
class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({required this.noteId, super.key});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(noteDetailsProvider(noteId));
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.checkoutTitle),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(RoutePaths.note(noteId)),
        ),
      ),
      body: note.when(
        loading: () => const LoadingView(),
        error: (_, _) => ErrorView(
          onRetry: () => ref.invalidate(noteDetailsProvider(noteId)),
        ),
        data: (n) => n == null || n.isFree
            ? EmptyView(
                icon: Icons.search_off,
                title: AppStrings.noteNotFoundTitle,
                message: AppStrings.payErrNotAvailable,
                action: FilledButton(
                  onPressed: () => context.go(RoutePaths.note(noteId)),
                  child: const Text(AppStrings.browseAllNotes),
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.all(context.pagePadding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _CheckoutCard(note: n),
                  ),
                ),
              ),
      ),
    );
  }
}

class _CheckoutCard extends ConsumerWidget {
  const _CheckoutCard({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(checkoutControllerProvider(note.id));
    final owned = ref.watch(ownsNoteProvider(note.id)).value ?? false;
    final canBuy = ref.watch(buyInAppProvider);

    if (state.step == CheckoutStep.success || owned) {
      return _Success(noteId: note.id);
    }

    final price = Money.format(note.price);
    final color = scheme.primary.toARGB32() & 0xFFFFFF;
    Future<void> pay() => ref
        .read(checkoutControllerProvider(note.id).notifier)
        .pay(
          noteTitle: note.title,
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
                NoteCover(
                  title: note.title,
                  thumbnailUrl: note.thumbnailUrl,
                  width: 72,
                  height: 72,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(note.title, style: text.titleMedium),
                      if (note.subjectName.isNotEmpty)
                        Text(note.subjectName, style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Text(AppStrings.checkoutTotal, style: text.titleMedium),
                const Spacer(),
                Text(price, style: text.headlineSmall),
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
              BuyOnWebsiteButton(noteId: note.id)
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
            Wrap(
              children: [
                Text(AppStrings.checkoutTerms, style: text.bodySmall),
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
  const _Success({required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
            FilledButton(
              onPressed: () => context.go(RoutePaths.noteViewer(noteId)),
              child: const Text(AppStrings.readNow),
            ),
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
