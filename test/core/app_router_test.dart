import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prepnotes/app.dart';
import 'package:prepnotes/core/constants/app_strings.dart';
import 'package:prepnotes/core/router/app_router.dart';
import 'package:prepnotes/core/router/route_paths.dart';
import 'package:prepnotes/features/auth/data/auth_session_provider.dart';
import 'package:prepnotes/features/auth/domain/auth_session.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late ProviderContainer container;
  late GoRouter router;

  Future<void> pumpApp(WidgetTester tester) async {
    container = ProviderContainer();
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
    expect(pageTitle(AppStrings.pageLogin), findsOneWidget);

    container
        .read(authControllerProvider.notifier)
        .debugSignInAs(AuthSession.student);
    await tester.pumpAndSettle();
    expect(location(), RoutePaths.profile);
  });

  testWidgets('student is kept out of admin; admin gets in', (tester) async {
    await pumpApp(tester);
    final auth = container.read(authControllerProvider.notifier)
      ..debugSignInAs(AuthSession.student);
    await go(tester, RoutePaths.adminOrders);
    expect(location(), RoutePaths.home);

    auth.debugSignInAs(AuthSession.admin);
    await go(tester, RoutePaths.adminOrder('o1'));
    expect(pageTitle(AppStrings.pageAdminOrder), findsOneWidget);
    expect(find.text('orderId: o1'), findsOneWidget);
  });
}
