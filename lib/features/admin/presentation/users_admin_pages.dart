import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/admin_stats.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../auth/data/auth_repository.dart';
import 'admin_ops_controllers.dart';
import 'orders_admin_pages.dart';
import 'widgets/admin_widgets.dart';

final _day = DateFormat('d MMM yyyy');

/// Active / Disabled + Admin chips for a user.
class UserStatusChips extends StatelessWidget {
  const UserStatusChips({required this.user, super.key});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget chip(String label, Color color) => Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: color, fontWeight: FontWeight.w600),
      side: BorderSide(color: color),
    );
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        user.disabled
            ? chip(AppStrings.userDisabled, scheme.error)
            : chip(AppStrings.userActive, context.appColors.success),
        if (user.isAdmin) chip(AppStrings.roleAdmin, scheme.primary),
      ],
    );
  }
}

/// `/admin/users` — every account, newest first, with search.
class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  String _search = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _search = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = adminUsersProvider(_search);
    return AdminPage(
      title: AppStrings.adminUsers,
      filters: TextField(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: AppStrings.searchUsersHint,
        ),
        onChanged: _onSearch,
      ),
      child: ref
          .watch(provider)
          .when(
            loading: () => const LoadingView(),
            error: (_, _) => ErrorView(onRetry: () => ref.invalidate(provider)),
            data: (page) => page.items.isEmpty
                ? const EmptyView(
                    icon: Icons.person_search_outlined,
                    title: AppStrings.noUsersFound,
                    message: '',
                  )
                : AdminTable<AdminUser>(
                    items: page.items,
                    title: (u) => u.profile.name,
                    subtitle: (u) => [
                      u.profile.email,
                      if (u.disabled) AppStrings.userDisabled,
                      if (u.isAdmin) AppStrings.roleAdmin,
                    ].join(' · '),
                    leading: (u) => UserAvatar(
                      initials: u.profile.initials,
                      photoUrl: u.profile.photoUrl,
                      radius: 18,
                    ),
                    columns: [
                      AdminColumn(
                        AppStrings.userColumnName,
                        (u) => Text(u.profile.name),
                      ),
                      AdminColumn(
                        AppStrings.userColumnEmail,
                        (u) => Text(u.profile.email),
                      ),
                      AdminColumn(
                        AppStrings.userColumnJoined,
                        (u) => Text(
                          u.profile.createdAt == null
                              ? '—'
                              : _day.format(u.profile.createdAt!),
                        ),
                      ),
                      AdminColumn(
                        AppStrings.userColumnStatus,
                        (u) => UserStatusChips(user: u),
                      ),
                    ],
                    actions: (u) => [
                      IconButton(
                        tooltip: AppStrings.pageAdminUser,
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () =>
                            context.go(RoutePaths.adminUser(u.uid)),
                      ),
                    ],
                    footer: loadMoreButton(
                      hasMore: page.hasMore,
                      loading: page.loadingMore,
                      onPressed: () => ref.read(provider.notifier).loadMore(),
                    ),
                  ),
          ),
    );
  }
}

/// `/admin/users/:uid`
class AdminUserPage extends ConsumerWidget {
  const AdminUserPage({required this.uid, super.key});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = adminUserProvider(uid);
    return ref
        .watch(provider)
        .when(
          loading: () => const LoadingView(),
          error: (_, _) => ErrorView(onRetry: () => ref.invalidate(provider)),
          data: (u) => u == null
              ? const EmptyView(
                  icon: Icons.person_off_outlined,
                  title: AppStrings.userNotFound,
                  message: '',
                )
              : _UserDetails(user: u),
        );
  }
}

class _UserDetails extends ConsumerWidget {
  const _UserDetails({required this.user});

  final AdminUser user;

  Future<void> _toggleDisabled(BuildContext context, WidgetRef ref) async {
    final disable = !user.disabled;
    if (disable &&
        !await confirmAction(
          context,
          title: AppStrings.disableConfirmTitle,
          message: AppStrings.disableConfirmMessage,
          confirm: AppStrings.disableAccount,
          destructive: true,
        )) {
      return;
    }
    if (!context.mounted) return;
    final ok = await runAdminAction(
      context,
      () => ref
          .read(adminRepositoryProvider)
          .setUserDisabled(user.uid, disabled: disable),
      success: disable ? AppStrings.accountDisabled : AppStrings.accountEnabled,
    );
    if (ok) _refresh(ref);
  }

  Future<void> _toggleAdmin(BuildContext context, WidgetRef ref) async {
    final make = !user.isAdmin;
    if (!await confirmAction(
      context,
      title: make ? AppStrings.makeAdmin : AppStrings.removeAdmin,
      message: make
          ? AppStrings.makeAdminConfirm
          : AppStrings.removeAdminConfirm,
      confirm: make ? AppStrings.makeAdmin : AppStrings.removeAdmin,
      destructive: !make,
    )) {
      return;
    }
    if (!context.mounted) return;
    final ok = await runAdminAction(
      context,
      () => ref
          .read(adminRepositoryProvider)
          .setAdmin(user.profile.email, admin: make),
      success: AppStrings.adminUpdated,
    );
    if (ok) _refresh(ref);
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(adminUserProvider(user.uid));
    ref.invalidate(adminUsersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final p = user.profile;
    final isMe =
        ref.watch(authSessionProvider.select((s) => s.value?.uid)) == user.uid;
    final purchases = ref.watch(adminUserPurchasesProvider(user.uid));
    final orders = ref.watch(adminUserOrdersProvider(user.uid));

    final header = Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 20,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            UserAvatar(initials: p.initials, photoUrl: p.photoUrl, radius: 32),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: text.headlineSmall),
                SelectableText(p.email, style: text.bodyMedium),
                const SizedBox(height: 6),
                UserStatusChips(user: user),
                const SizedBox(height: 6),
                Text(
                  [
                    if (p.createdAt != null)
                      AppStrings.joinedOn(_day.format(p.createdAt!)),
                    if (p.lastLoginAt != null)
                      AppStrings.lastLogin(_day.format(p.lastLoginAt!)),
                    '${AppStrings.userStudyTime}: '
                        '${AppStrings.studyMinutes(p.totalStudyMinutes)}',
                  ].join(' · '),
                  style: text.bodySmall,
                ),
                SelectableText('UID ${user.uid}', style: text.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!isMe && !user.isAdmin)
          OutlinedButton.icon(
            onPressed: () => _toggleDisabled(context, ref),
            icon: Icon(user.disabled ? Icons.lock_open : Icons.block),
            label: Text(
              user.disabled
                  ? AppStrings.enableAccount
                  : AppStrings.disableAccount,
            ),
          ),
        if (!isMe)
          OutlinedButton.icon(
            onPressed: () => _toggleAdmin(context, ref),
            icon: Icon(
              user.isAdmin
                  ? Icons.remove_moderator_outlined
                  : Icons.admin_panel_settings_outlined,
            ),
            label: Text(
              user.isAdmin ? AppStrings.removeAdmin : AppStrings.makeAdmin,
            ),
          ),
      ],
    );

    Widget section(String title, Widget child) => Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: text.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );

    Widget asyncList<T>(AsyncValue<List<T>> value, Widget Function(T) row) =>
        value.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text(AppStrings.loadFailed),
          data: (items) => items.isEmpty
              ? const Text(AppStrings.nothingYet)
              : Column(children: [for (final i in items) row(i)]),
        );

    return ListView(
      padding: EdgeInsets.all(context.pagePadding),
      children: [
        Text(AppStrings.pageAdminUser, style: text.headlineMedium),
        const SizedBox(height: 16),
        header,
        const SizedBox(height: 12),
        actions,
        const SizedBox(height: 20),
        section(
          AppStrings.userPurchases,
          asyncList(
            purchases,
            (pur) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(pur.title),
              subtitle: Text(
                pur.purchasedAt == null ? '' : _day.format(pur.purchasedAt!),
              ),
              trailing: Text(Money.format(pur.pricePaid)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        section(
          AppStrings.userOrders,
          asyncList(
            orders,
            (o) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(o.noteTitles.join(', ')),
              subtitle: Text(
                o.createdAt == null ? o.id : _day.format(o.createdAt!),
              ),
              trailing: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(Money.format(o.amount)),
                  OrderStatusChip(status: o.status),
                ],
              ),
              onTap: () => context.go(RoutePaths.adminOrder(o.id)),
            ),
          ),
        ),
      ],
    );
  }
}
