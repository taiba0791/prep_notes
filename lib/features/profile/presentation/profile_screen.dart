import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/services/photo_picker.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/theme_mode_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/university.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/university_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/current_user_providers.dart';
import '../../auth/domain/auth_session.dart';
import 'account_controllers.dart';
import 'delete_account_dialog.dart';
import 'profile_controllers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider);
    final session = ref.watch(authSessionProvider).value ?? AuthSession.guest;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.navProfile),
        actions: [if (context.isMobile) const ThemeModeButton()],
      ),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (_, _) => ErrorView(
          onRetry: () => ref.invalidate(currentUserProfileProvider),
        ),
        data: (p) => p == null
            // Signed in, but the profile document isn't there yet.
            ? EmptyView(
                icon: Icons.hourglass_top,
                title: AppStrings.profileSettingUpTitle,
                message: AppStrings.profileSettingUpMessage,
                action: OutlinedButton(
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  child: const Text(AppStrings.signOut),
                ),
              )
            : _ProfileContent(profile: p, session: session),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.profile, required this.session});

  final UserProfile profile;
  final AuthSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = context.responsive(mobile: 1, tablet: 3);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: ListView(
          padding: EdgeInsets.all(context.pagePadding),
          children: [
            _Header(profile: profile, isAdmin: session.isAdmin),
            if (!session.emailVerified) ...[
              const SizedBox(height: 20),
              const _VerifyEmailBanner(),
            ],
            const SizedBox(height: 24),
            _AcademicCard(profile: profile),
            const SizedBox(height: 16),
            _StatsGrid(profile: profile, columns: columns),
            const SizedBox(height: 16),
            _Links(session: session),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.isAdmin});

  final UserProfile profile;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        _EditableAvatar(profile: profile),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.name, style: text.headlineSmall),
              const SizedBox(height: 4),
              Text(profile.email, style: text.bodyMedium),
              if (isAdmin) ...[
                const SizedBox(height: 8),
                Chip(
                  avatar: Icon(
                    Icons.verified_user,
                    size: 16,
                    color: scheme.onTertiary,
                  ),
                  label: const Text(AppStrings.adminBadge),
                  backgroundColor: scheme.tertiary,
                  labelStyle: text.labelMedium?.copyWith(
                    color: scheme.onTertiary,
                  ),
                  side: BorderSide.none,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Avatar with a small camera badge. Tap → gallery / camera / remove.
class _EditableAvatar extends ConsumerWidget {
  const _EditableAvatar({required this.profile});

  final UserProfile profile;

  Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(avatarControllerProvider.notifier);
    final hasPhoto = profile.photoUrl?.isNotEmpty ?? false;

    final choice = await showModalBottomSheet<_PhotoAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text(AppStrings.photoFromGallery),
              onTap: () => Navigator.pop(context, _PhotoAction.gallery),
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text(AppStrings.photoFromCamera),
                onTap: () => Navigator.pop(context, _PhotoAction.camera),
              ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text(AppStrings.photoRemove),
                onTap: () => Navigator.pop(context, _PhotoAction.remove),
              ),
          ],
        ),
      ),
    );

    switch (choice) {
      case _PhotoAction.gallery:
        await controller.change(profile.uid, PhotoSource.gallery);
      case _PhotoAction.camera:
        await controller.change(profile.uid, PhotoSource.camera);
      case _PhotoAction.remove:
        await controller.remove(profile.uid);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(avatarControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    ref.listen(avatarControllerProvider, (_, next) {
      final message = next.isLoading ? null : next.value;
      if (message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    });

    return Tooltip(
      message: AppStrings.changePhoto,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: state.isLoading ? null : () => _openMenu(context, ref),
        child: Stack(
          alignment: Alignment.center,
          children: [
            UserAvatar(initials: profile.initials, photoUrl: profile.photoUrl),
            if (state.isLoading)
              const SizedBox.square(
                dimension: 80,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: scheme.primary,
                child: Icon(
                  Icons.photo_camera,
                  size: 16,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PhotoAction { gallery, camera, remove }

class _VerifyEmailBanner extends ConsumerWidget {
  const _VerifyEmailBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final state = ref.watch(emailVerificationControllerProvider);
    final controller = ref.read(emailVerificationControllerProvider.notifier);

    ref.listen(emailVerificationControllerProvider, (_, next) {
      final message = next.hasError
          ? AppStrings.authErrorUnknown
          : next.isLoading
          ? null
          : next.value;
      if (message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    });

    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  color: scheme.onTertiaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppStrings.verifyEmailTitle,
                    style: text.titleMedium?.copyWith(
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.verifyEmailMessage,
              style: text.bodyMedium?.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: state.isLoading ? null : controller.resend,
                  child: const Text(AppStrings.verifyEmailResend),
                ),
                TextButton(
                  onPressed: state.isLoading ? null : controller.checkAgain,
                  child: const Text(AppStrings.verifyEmailDone),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AcademicCard extends ConsumerWidget {
  const _AcademicCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final universities = ref.watch(activeUniversitiesProvider);
    final universityName = switch (profile.universityId) {
      null => AppStrings.notSet,
      final id =>
        universities.value
                ?.cast<University?>()
                .firstWhere((u) => u!.id == id, orElse: () => null)
                ?.name ??
            AppStrings.notSet,
    };
    final semester = profile.semester;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: const Text(AppStrings.fieldUniversity),
            subtitle: Text(universityName),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text(AppStrings.fieldSemester),
            subtitle: Text(
              semester == null
                  ? AppStrings.notSet
                  : AppStrings.semesterLabel(semester),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text(AppStrings.editProfile),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(RoutePaths.profileEdit),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.profile, required this.columns});

  final UserProfile profile;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      const _StatTile(
        icon: Icons.receipt_long_outlined,
        label: AppStrings.statPurchases,
        value: '—',
        hint: AppStrings.comingSoon,
      ),
      _StatTile(
        icon: Icons.timer_outlined,
        label: AppStrings.statStudyTime,
        value: AppStrings.studyMinutes(profile.totalStudyMinutes),
      ),
      const _StatTile(
        icon: Icons.history,
        label: AppStrings.statRecentlyViewed,
        value: '—',
        hint: AppStrings.comingSoon,
      ),
    ];

    if (columns == 1) {
      return Column(
        children: [
          for (final t in tiles) ...[t, const SizedBox(height: 12)],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.secondaryContainer,
              child: Icon(icon, color: scheme.onSecondaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: text.labelLarge),
                  Text(value, style: text.titleLarge),
                  if (hint != null) Text(hint!, style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Links extends ConsumerWidget {
  const _Links({required this.session});

  final AuthSession session;

  Future<void> _deleteAccount(BuildContext context) async {
    // Grab these now: once the account is gone the router leaves this page,
    // so this widget's context won't be usable any more.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await showDeleteAccountDialog(
      context,
      hasPassword: session.hasPassword,
      onDeleted: () {
        router.go(RoutePaths.home);
        messenger.showSnackBar(
          const SnackBar(content: Text(AppStrings.accountDeleted)),
        );
      },
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.signOutConfirmTitle),
        content: const Text(AppStrings.signOutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.signOut),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.shopping_bag_outlined),
            title: const Text(AppStrings.linkMyPurchases),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(RoutePaths.purchases),
          ),
          if (session.isAdmin) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text(AppStrings.linkAdminPanel),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(RoutePaths.admin),
            ),
          ],
          if (session.hasPassword) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text(AppStrings.changePassword),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(RoutePaths.profileChangePassword),
            ),
          ],
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout, color: scheme.error),
            title: Text(
              AppStrings.signOut,
              style: TextStyle(color: scheme.error),
            ),
            onTap: () => _confirmSignOut(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
            title: Text(
              AppStrings.deleteAccount,
              style: TextStyle(color: scheme.error),
            ),
            onTap: () => _deleteAccount(context),
          ),
        ],
      ),
    );
  }
}
