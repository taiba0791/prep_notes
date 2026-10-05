import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prepnotes/app.dart';
import 'package:prepnotes/core/constants/app_strings.dart';
import 'package:prepnotes/core/router/app_router.dart';
import 'package:prepnotes/core/router/route_paths.dart';
import 'package:prepnotes/data/repositories/user_repository.dart';
import 'package:prepnotes/features/auth/data/auth_repository.dart';
import 'package:prepnotes/features/auth/domain/auth_session.dart';

import '../fakes/fake_auth_repository.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late ProviderContainer container;
  late GoRouter router;
  late FakeAuthRepository auth;

  const student = AuthSession(uid: 'student1');
  const admin = AuthSession(uid: 'admin1', isAdmin: true);

  Future<void> pumpApp(WidgetTester tester) async {
    auth = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(
          FirestoreUserRepository(FakeFirebaseFirestore()),
        ),
      ],
    );
    addTearDown(container.dispose);
    router = container.read(appRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const PrepNotesApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> go(WidgetTester tester, String location) async {
    router.go(location);
    await tester.pumpAndSettle();
  }

  String location() => router.state.uri.toString();
  Finder pageTitle(String title) => find.widgetWithText(AppBar, title);

  testWidgets('starts on Home', (tester) async {
    await pumpApp(tester);
    expect(location(), RoutePaths.home);
    expect(pageTitle(AppStrings.navHome), findsOneWidget);
  });

  testWidgets('tapping a tab changes the URL', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text(AppStrings.navResources));
    await tester.pumpAndSettle();
    expect(location(), RoutePaths.resources);
    expect(pageTitle(AppStrings.navResources), findsOneWidget);
  });

  testWidgets('deep link shows the page with its URL parameter', (
    tester,
  ) async {
    await pumpApp(tester);
    await go(tester, RoutePaths.university('mumbai-univ'));
    expect(pageTitle(AppStrings.pageUniversity), findsOneWidget);
    expect(find.text('universityId: mumbai-univ'), findsOneWidget);
  });

  testWidgets('unknown URL shows the 404 page', (tester) async {
    await pumpApp(tester);
    await go(tester, '/this/does/not/exist');
    expect(find.text(AppStrings.notFoundTitle), findsOneWidget);
  });

  testWidgets('guest → login → signed in → back to the remembered page', (
    tester,
  ) async {
    await pumpApp(tester);
    await go(tester, RoutePaths.profile);
    expect(location(), '/login?from=%2Fprofile');
    expect(find.text(AppStrings.loginTitle), findsOneWidget);

    auth.emit(student);
    await tester.pumpAndSettle();
    expect(location(), RoutePaths.profile);
  });

  testWidgets('student is kept out of admin; admin gets in', (tester) async {
    await pumpApp(tester);
    auth.emit(student);
    await tester.pumpAndSettle();
    await go(tester, RoutePaths.adminOrders);
    expect(location(), RoutePaths.home);

    auth.emit(admin);
    await tester.pumpAndSettle();
    await go(tester, RoutePaths.adminOrder('o1'));
    expect(pageTitle(AppStrings.pageAdminOrder), findsOneWidget);
    expect(find.text('orderId: o1'), findsOneWidget);
  });

  testWidgets('signing out on a protected page goes to login', (tester) async {
    await pumpApp(tester);
    auth.emit(student);
    await tester.pumpAndSettle();
    await go(tester, RoutePaths.profile);
    expect(location(), RoutePaths.profile);

    // No profile document in the fake DB → "setting up" view with Log out.
    await tester.tap(find.text(AppStrings.signOut));
    await tester.pumpAndSettle();
    expect(location(), '/login?from=%2Fprofile');
  });
}
