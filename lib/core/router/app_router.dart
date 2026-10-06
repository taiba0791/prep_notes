import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/admin/presentation/admin_dashboard_page.dart';
import '../../features/admin/presentation/admin_scaffold.dart';
import '../../features/admin/presentation/catalog_pages.dart';
import '../../features/admin/presentation/notes_admin_pages.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/auth_session.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/notes/presentation/browse_screens.dart';
import '../../features/notes/presentation/note_details_screen.dart';
import '../../features/notes/presentation/preview_and_search_screens.dart';
import '../../features/profile/presentation/change_password_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
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
          currentPath: state.uri.path,
          // Tapping the current tab again returns to that tab's first page.
          onDestinationSelected: (index) => shell.goBranch(
            index,
            initialLocation: index == shell.currentIndex,
          ),
          onNavigate: (path) => GoRouter.of(context).go(path),
          child: shell,
        ),
        branches: [
          // 0 · Home (+ search and footer pages)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                builder: (context, state) => const HomeScreen(),
              ),
              GoRoute(
                path: RoutePaths.search,
                builder: (context, state) => SearchScreen(
                  initialQuery:
                      state.uri.queryParameters[RoutePaths.queryParam] ?? '',
                ),
              ),
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
                builder: (context, state) => const NotesHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'u/:universityId',
                    builder: (context, state) => UniversityScreen(
                      universityId: state.pathParameters['universityId']!,
                    ),
                  ),
                  GoRoute(
                    path: 's/:semesterId',
                    builder: (context, state) => SemesterScreen(
                      semesterId: state.pathParameters['semesterId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'sub/:subjectId',
                    builder: (context, state) => SubjectScreen(
                      subjectId: state.pathParameters['subjectId']!,
                    ),
                  ),
                  GoRoute(
                    path: ':noteId',
                    builder: (context, state) => NoteDetailsScreen(
                      noteId: state.pathParameters['noteId']!,
                    ),
                    routes: [
                      // Free preview pages (public, full screen).
                      GoRoute(
                        path: 'preview',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => NotePreviewScreen(
                          noteId: state.pathParameters['noteId']!,
                        ),
                      ),
                      // Full purchased PDF (Phase 4).
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
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                  GoRoute(
                    path: 'change-password',
                    builder: (context, state) => const ChangePasswordScreen(),
                  ),
                ],
              ),
              _page(RoutePaths.purchases, AppStrings.pagePurchases),
            ],
          ),
        ],
      ),

      // Auth (full screen, no navigation)
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => LoginScreen(from: _from(state)),
      ),
      GoRoute(
        path: RoutePaths.register,
        builder: (context, state) => RegisterScreen(from: _from(state)),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        builder: (context, state) => ForgotPasswordScreen(from: _from(state)),
      ),

      // Checkout (full screen)
      _page('/checkout/:noteId', AppStrings.pageCheckout),

      // Admin panel: its own shell (dark side menu), guarded by adminGuard.
      ShellRoute(
        builder: (context, state, child) =>
            AdminScaffold(currentPath: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: RoutePaths.admin,
            builder: (context, state) => const AdminDashboardPage(),
            routes: [
              GoRoute(
                path: 'universities',
                builder: (context, state) => const AdminUniversitiesPage(),
              ),
              GoRoute(
                path: 'semesters',
                builder: (context, state) => const AdminSemestersPage(),
              ),
              GoRoute(
                path: 'subjects',
                builder: (context, state) => const AdminSubjectsPage(),
              ),
              GoRoute(
                path: 'modules',
                builder: (context, state) => const AdminModulesPage(),
              ),
              GoRoute(
                path: 'notes',
                builder: (context, state) => const AdminNotesPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const AdminNoteFormPage(),
                  ),
                  GoRoute(
                    path: ':noteId/edit',
                    builder: (context, state) => AdminNoteFormPage(
                      noteId: state.pathParameters['noteId'],
                    ),
                  ),
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
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
}

String? _from(GoRouterState state) =>
    state.uri.queryParameters[RoutePaths.fromParam];

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
