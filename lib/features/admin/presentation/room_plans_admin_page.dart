import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/access.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../purchases/presentation/purchases_controllers.dart';
import 'widgets/admin_widgets.dart';

/// `/admin/room-plans` — prices of the Resource Room subscriptions.
class AdminRoomPlansPage extends ConsumerWidget {
  const AdminRoomPlansPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(roomPlansProvider);
    return AdminPage(
      title: AppStrings.adminRoomPlans,
      filters: Text(
        AppStrings.roomPlansSubtitle,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      child: plans.when(
        loading: () => const LoadingView(),
        error: (_, _) =>
            ErrorView(onRetry: () => ref.invalidate(roomPlansProvider)),
        data: (list) => ListView(
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final p in list)
                  SizedBox(
                    width: context.isMobile ? double.infinity : 280,
                    child: _PlanCard(plan: p),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends ConsumerStatefulWidget {
  const _PlanCard({required this.plan});

  final RoomPlan plan;

  @override
  ConsumerState<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<_PlanCard> {
  final _form = GlobalKey<FormState>();
  late final _price = TextEditingController(
    text: Money.toRupeesText(widget.plan.price),
  );
  bool _saving = false;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final price = Money.parseRupees(_price.text)!;
    if (price == widget.plan.price) return;
    setState(() => _saving = true);
    final ok = await runAdminAction(
      context,
      () => ref
          .read(adminRepositoryProvider)
          .setRoomPlanPrice(widget.plan.key, price),
      success: AppStrings.priceUpdated,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) ref.invalidate(roomPlansProvider);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${AppStrings.roomTitle} · ${AppStrings.planName(widget.plan.months)}',
                style: text.titleMedium,
              ),
              Text(
                AppStrings.perMonths(widget.plan.months),
                style: text.bodySmall,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: AppStrings.priceLabel,
                ),
                validator: (v) {
                  final p = Money.parseRupees(v ?? '');
                  return p == null || p < 100 || p > 10000000
                      ? AppStrings.priceInvalid
                      : null;
                },
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text(AppStrings.roomSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
