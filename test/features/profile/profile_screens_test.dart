import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prepnotes/core/constants/app_strings.dart';
import 'package:prepnotes/core/constants/firestore_paths.dart';
import 'package:prepnotes/core/router/route_paths.dart';
import 'package:prepnotes/core/theme/app_theme.dart';
import 'package:prepnotes/data/repositories/university_repository.dart';
import 'package:prepnotes/data/repositories/user_repository.dart';
import 'package:prepnotes/features/auth/data/auth_repository.dart';
import 'package:prepnotes/features/auth/domain/auth_session.dart';
import 'package:prepnotes/features/profile/presentation/edit_profile_screen.dart';
import 'package:prepnotes/features/profile/presentation/profile_screen.dart';

import '../../fakes/fake_auth_repository.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeAuthRepository auth;
  late FakeFirebaseFirestore db;

  Future<void> seedProfile({String? universityId, int? semester}) =>
      db.doc(FirestorePaths.user('u1')).set({
        UserFields.name: 'Taiba Shaikh',
        UserFields.email: 'taiba@x.com',
        UserFields.role: UserRole.student,
        UserFields.totalStudyMinutes: 135,
        UserFields.universityId: ?universityId,
        UserFields.semester: ?semester,
      });

  Future<void> seedUniversities() async {
    await db.doc(FirestorePaths.university('mu')).set({
      UniversityFields.name: 'University of Mumbai',
      UniversityFields.order: 1,
      UniversityFields.isActive: true,
    });
    await db.doc(FirestorePaths.university('old')).set({
      UniversityFields.name: 'Closed University',
      UniversityFields.order: 2,
      UniversityFields.isActive: false,
    });
  }

  /// Pumps the profile pages with a tiny router and fake backends.
  Future<void> pump(
    WidgetTester tester, {
    required AuthSession session,
    String start = RoutePaths.profile,
    double width = 1200,
  }) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    auth = FakeAuthRepository(session);
    final router = GoRouter(
      initialLocation: start,
      routes: [
        GoRoute(
          path: RoutePaths.profile,
          builder: (_, _) => const ProfileScreen(),
          routes: [
            GoRoute(path: 'edit', builder: (_, _) => const EditProfileScreen()),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(FirestoreUserRepository(db)),
          universityRepositoryProvider.overrideWithValue(
            FirestoreUniversityRepository(db),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  const student = AuthSession(
    uid: 'u1',
    email: 'taiba@x.com',
    emailVerified: true,
  );

  setUp(() => db = FakeFirebaseFirestore());

  group('Profile screen', () {
    testWidgets('shows name, email, initials and real study time', (
      tester,
    ) async {
      await seedProfile();
      await pump(tester, session: student);

      expect(find.text('Taiba Shaikh'), findsOneWidget);
      expect(find.text('taiba@x.com'), findsOneWidget);
      expect(find.text('TS'), findsOneWidget);
      expect(find.text('2 h 15 min'), findsOneWidget);
      expect(find.text(AppStrings.notSet), findsNWidgets(2));
      expect(find.text(AppStrings.verifyEmailTitle), findsNothing);
      expect(find.text(AppStrings.adminBadge), findsNothing);
      expect(find.text(AppStrings.linkAdminPanel), findsNothing);
    });

    testWidgets('fits a 360 px phone (no overflow), banner included', (
      tester,
    ) async {
      await seedUniversities();
      await seedProfile(universityId: 'mu', semester: 3);
      await pump(
        tester,
        session: student.copyWith(emailVerified: false, isAdmin: true),
        width: 360,
      );
      expect(find.text('Taiba Shaikh'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows university name and semester when set', (tester) async {
      await seedUniversities();
      await seedProfile(universityId: 'mu', semester: 3);
      await pump(tester, session: student);

      expect(find.text('University of Mumbai'), findsOneWidget);
      expect(find.text(AppStrings.semesterLabel(3)), findsOneWidget);
    });

    testWidgets('admins see the badge and the Admin panel link', (
      tester,
    ) async {
      await seedProfile();
      await pump(tester, session: student.copyWith(isAdmin: true));
      expect(find.text(AppStrings.adminBadge), findsOneWidget);
      expect(find.text(AppStrings.linkAdminPanel), findsOneWidget);
    });

    testWidgets('unverified email: banner, resend and re-check', (
      tester,
    ) async {
      await seedProfile();
      await pump(tester, session: student.copyWith(emailVerified: false));

      expect(find.text(AppStrings.verifyEmailTitle), findsOneWidget);
      await tester.tap(find.text(AppStrings.verifyEmailResend));
      await tester.pumpAndSettle();
      expect(auth.calls, contains('verify'));
      expect(find.text(AppStrings.verifyEmailSent), findsOneWidget);

      await tester.tap(find.text(AppStrings.verifyEmailDone));
      await tester.pumpAndSettle();
      expect(auth.calls, contains('refresh'));
    });

    testWidgets('profile not created yet: friendly empty state + log out', (
      tester,
    ) async {
      await pump(tester, session: student);
      expect(find.text(AppStrings.profileSettingUpTitle), findsOneWidget);
      await tester.tap(find.text(AppStrings.signOut));
      await tester.pumpAndSettle();
      expect(auth.calls, contains('signOut'));
    });

    testWidgets('log out asks for confirmation first', (tester) async {
      await seedProfile();
      await pump(tester, session: student);

      await tester.tap(find.widgetWithText(ListTile, AppStrings.signOut));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.signOutConfirmTitle), findsOneWidget);

      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();
      expect(auth.calls, isNot(contains('signOut')));

      await tester.tap(find.widgetWithText(ListTile, AppStrings.signOut));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.signOut));
      await tester.pumpAndSettle();
      expect(auth.calls, contains('signOut'));
    });
  });

  group('Edit profile', () {
    testWidgets('saves name, university and semester, then goes back', (
      tester,
    ) async {
      await seedUniversities();
      await seedProfile();
      await pump(tester, session: student, start: RoutePaths.profileEdit);

      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.fieldName),
        'Taiba S',
      );
      await tester.tap(find.text(AppStrings.fieldUniversity));
      await tester.pumpAndSettle();
      expect(find.text('Closed University'), findsNothing);
      await tester.tap(find.text('University of Mumbai').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.fieldSemester));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.semesterLabel(4)).last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.save));
      await tester.pumpAndSettle();

      final data = (await db.doc(FirestorePaths.user('u1')).get()).data()!;
      expect(data[UserFields.name], 'Taiba S');
      expect(data[UserFields.universityId], 'mu');
      expect(data[UserFields.semester], 4);
      // Back on the profile page, with a confirmation.
      expect(find.text(AppStrings.editProfile), findsOneWidget);
      expect(find.text(AppStrings.profileSaved), findsOneWidget);
    });

    testWidgets('invalid name is not saved', (tester) async {
      await seedProfile();
      await pump(tester, session: student, start: RoutePaths.profileEdit);
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.fieldName),
        'T',
      );
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.save));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.validationNameShort), findsOneWidget);
      final data = (await db.doc(FirestorePaths.user('u1')).get()).data()!;
      expect(data[UserFields.name], 'Taiba Shaikh');
    });

    testWidgets('no universities yet: friendly hint instead of a dropdown', (
      tester,
    ) async {
      await seedProfile();
      await pump(tester, session: student, start: RoutePaths.profileEdit);
      expect(find.text(AppStrings.noUniversitiesYet), findsOneWidget);
    });
  });
}
