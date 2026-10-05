import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/auth_session.dart';
import '../constants/app_strings.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/not_found_screen.dart';
import '../widgets/placeholder_screen.dart';
import 'route_guards.dart';
import 'route_paths.dart';

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// The app's single [GoRouter].
///
/// - The 5 main tabs are branches of a [StatefulShellRoute] wrapped in
///   [AppScaffold]; each tab keeps its own back-stack.
/// - Auth/admin/legal/full-screen pages sit outside the shell.
/// - Guards run in `redirect` and re-run whenever the [AuthSession] changes.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // Tell the router to re-check guards when sign-in state changes, without
  // rebuilding the router itself. While Firebase is still restoring the
  // session, the value is AuthSession.loading.
  AuthSession current() =>
      ref.read(authSessionProvider).value ?? AuthSession.loading;

  final authChanges = ValueNotifier<AuthSession>(current());
  ref
    ..listen(authSessionProvider, (_, _) => authChanges.value = current())
    ..onDispose(authChanges.dispose);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RoutePaths.home,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: authChanges,
    redirect: (context, state) =>
        guardRedirect(session: authChanges.value, uri: state.uri),
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppScaffold(
          selectedIndex: shell.currentIndex,
          // Tapping the current tab again returns to that tab's first page.
          onDestinationSelected: (index) => shell.goBranch(
            index,
            initialLocation: index == shell.currentIndex,
          ),
          child: shell,
        ),
        branches: [
          // 0 · Home (+ search and footer pages)
          StatefulShellBranch(
            routes: [
              _page(RoutePaths.home, AppStrings.navHome),
              _page(RoutePaths.search, AppStrings.pageSearch),
              _page(RoutePaths.about, AppStrings.pageAbout),
              _page(RoutePaths.contact, AppStrings.pageContact),
              _page(RoutePaths.privacy, AppStrings.pagePrivacy),
              _page(RoutePaths.terms, AppStrings.pageTerms),
              _page(RoutePaths.refundPolicy, AppStrings.pageRefundPolicy),
            ],
          ),
          // 1 · Notes: University → Semester → Subject → Note
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.notes,
                builder: (context, state) =>
                    const PlaceholderScreen(title: AppStrings.navNotes),
                routes: [
                  _page('u/:universityId', AppStrings.pageUniversity),
                  _page('s/:semesterId', AppStrings.pageSemester),
                  _page('sub/:subjectId', AppStrings.pageSubject),
                  _page(
                    ':noteId',
                    AppStrings.pageNoteDetails,
                    routes: [
                      // Full-screen PDF viewer (hides the navigation).
                      _page(
                        'view',
                        AppStrings.pageNoteViewer,
                        parentNavigatorKey: _rootNavigatorKey,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // 2 · Study Zone (Student Voice lives here too)
          StatefulShellBranch(
            routes: [
              _page(RoutePaths.studyZone, AppStrings.navStudyZone),
              _page(RoutePaths.studentVoice, AppStrings.pageStudentVoice),
            ],
          ),
          // 3 · Resources
          StatefulShellBranch(
            routes: [_page(RoutePaths.resources, AppStrings.navResources)],
          ),
          // 4 · Profile (+ My Purchases)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.profile,
                builder: (context, state) => const PlaceholderScreen(
                  title: AppStrings.navProfile,
                  actions: [_SignOutButton()],
                ),
              ),
              _page(RoutePaths.purchases, AppStrings.pagePurchases),
            ],
          ),
        ],
      ),

      // Auth (full screen, no navigation)
      _page(RoutePaths.login, AppStrings.pageLogin),
      _page(RoutePaths.register, AppStrings.pageRegister),
      _page(RoutePaths.forgotPassword, AppStrings.pageForgotPassword),

      // Checkout (full screen)
      _page('/checkout/:noteId', AppStrings.pageCheckout),

      // Admin panel (Phase 2 adds its own side-navigation shell)
      GoRoute(
        path: RoutePaths.admin,
        builder: (context, state) =>
            const PlaceholderScreen(title: AppStrings.pageAdminDashboard),
        routes: [
          _page('universities', AppStrings.pageAdminUniversities),
          _page('semesters', AppStrings.pageAdminSemesters),
          _page('subjects', AppStrings.pageAdminSubjects),
          _page('modules', AppStrings.pageAdminModules),
          _page(
            'notes',
            AppStrings.pageAdminNotes,
            routes: [
              _page('new', AppStrings.pageAdminNoteNew),
              _page(':noteId/edit', AppStrings.pageAdminNoteEdit),
            ],
          ),
          _page(
            'users',
            AppStrings.pageAdminUsers,
            routes: [_page(':uid', AppStrings.pageAdminUser)],
          ),
          _page(
            'orders',
            AppStrings.pageAdminOrders,
            routes: [_page(':orderId', AppStrings.pageAdminOrder)],
          ),
          _page('resources', AppStrings.pageAdminResources),
          _page('student-voice', AppStrings.pageAdminStudentVoice),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
}

/// A route that shows a [PlaceholderScreen] with its URL parameters.
/// Each phase swaps these for real screens.
GoRoute _page(
  String path,
  String title, {
  List<RouteBase> routes = const [],
  GlobalKey<NavigatorState>? parentNavigatorKey,
}) {
  return GoRoute(
    path: path,
    parentNavigatorKey: parentNavigatorKey,
    builder: (context, state) =>
        PlaceholderScreen(title: title, params: state.pathParameters),
    routes: routes,
  );
}

/// Temporary until the Profile screen (Step 1.8).
class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton(
      onPressed: () => ref.read(authRepositoryProvider).signOut(),
      child: const Text(AppStrings.signOut),
    );
  }
}
