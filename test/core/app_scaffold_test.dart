import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prepnotes/core/constants/app_strings.dart';
import 'package:prepnotes/core/router/route_paths.dart';
import 'package:prepnotes/core/theme/app_theme.dart';
import 'package:prepnotes/core/widgets/app_scaffold.dart';
import 'package:prepnotes/features/auth/data/auth_repository.dart';
import 'package:prepnotes/features/auth/domain/auth_session.dart';

import '../fakes/fake_auth_repository.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  int? tappedTab;
  String? openedPath;

  Future<void> pumpAtWidth(
    WidgetTester tester,
    double width, {
    AuthSession session = AuthSession.guest,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tappedTab = null;
    openedPath = null;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(session)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: AppScaffold(
            selectedIndex: AppBranch.home,
            onDestinationSelected: (i) => tappedTab = i,
            onNavigate: (p) => openedPath = p,
            child: const Text('page body'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('phone: bottom bar with the 5 tabs', (tester) async {
    await pumpAtWidth(tester, 360);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text(AppStrings.navStudentVoice), findsNothing);
    expect(find.text('page body'), findsOneWidget);

    await tester.tap(find.text(AppStrings.navResources));
    expect(tappedTab, AppBranch.resources);
    expect(tester.takeException(), isNull);
  });

  for (final width in [700.0, 1300.0]) {
    testWidgets('${width.toInt()} px: design top nav for guests', (
      tester,
    ) async {
      await pumpAtWidth(tester, width);
      expect(find.byType(NavigationBar), findsNothing);
      for (final label in [
        AppStrings.navNotes,
        AppStrings.navStudyZone,
        AppStrings.navResourceRoom,
        AppStrings.navStudentVoice,
        AppStrings.loginButton,
        AppStrings.signUpFree,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(tester.takeException(), isNull, reason: 'no overflow');

      // Links sit in a horizontally scrollable row; bring each into view.
      await tester.ensureVisible(find.text(AppStrings.navResourceRoom));
      await tester.tap(find.text(AppStrings.navResourceRoom));
      expect(tappedTab, AppBranch.resources);

      await tester.ensureVisible(find.text(AppStrings.navStudentVoice));
      await tester.tap(find.text(AppStrings.navStudentVoice));
      expect(openedPath, RoutePaths.studentVoice);

      await tester.tap(find.text(AppStrings.signUpFree));
      expect(openedPath, RoutePaths.register);
    });
  }

  testWidgets('signed in: avatar instead of Log in / Sign up', (tester) async {
    await pumpAtWidth(tester, 1300, session: const AuthSession(uid: 'u1'));
    expect(find.text(AppStrings.signUpFree), findsNothing);
    await tester.tap(find.byTooltip(AppStrings.navProfile));
    expect(tappedTab, AppBranch.profile);
  });

  test('there are exactly 5 tab branches', () {
    expect(appDestinations.map((d) => d.label), [
      AppStrings.navHome,
      AppStrings.navNotes,
      AppStrings.navStudyZone,
      AppStrings.navResources,
      AppStrings.navProfile,
    ]);
  });
}
