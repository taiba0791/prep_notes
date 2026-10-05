import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prepnotes/core/constants/app_strings.dart';
import 'package:prepnotes/core/constants/firestore_paths.dart';
import 'package:prepnotes/core/router/route_paths.dart';
import 'package:prepnotes/core/services/photo_picker.dart';
import 'package:prepnotes/core/theme/app_theme.dart';
import 'package:prepnotes/data/repositories/avatar_repository.dart';
import 'package:prepnotes/data/repositories/university_repository.dart';
import 'package:prepnotes/data/repositories/user_repository.dart';
import 'package:prepnotes/features/auth/data/auth_repository.dart';
import 'package:prepnotes/features/auth/domain/auth_failure.dart';
import 'package:prepnotes/features/auth/domain/auth_session.dart';
import 'package:prepnotes/features/profile/presentation/change_password_screen.dart';
import 'package:prepnotes/features/profile/presentation/profile_screen.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_media.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeAuthRepository auth;
  late FakeFirebaseFirestore db;
  late FakePhotoPicker picker;
  late FakeAvatarRepository avatars;

  const emailUser = AuthSession(
    uid: 'u1',
    email: 'taiba@x.com',
    emailVerified: true,
    hasPassword: true,
  );
  const googleUser = AuthSession(
    uid: 'u1',
    email: 'taiba@gmail.com',
    emailVerified: true,
  );

  Future<void> pump(
    WidgetTester tester, {
    required AuthSession session,
    String start = RoutePaths.profile,
  }) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    auth = FakeAuthRepository(session);
    db = FakeFirebaseFirestore();
    picker = FakePhotoPicker();
    avatars = FakeAvatarRepository();
    await db.doc(FirestorePaths.user('u1')).set({
      UserFields.name: 'Taiba Shaikh',
      UserFields.email: session.email,
      UserFields.role: UserRole.student,
    });

    final router = GoRouter(
      initialLocation: start,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, _) => const Scaffold(body: Text('HOME')),
        ),
        GoRoute(
          path: RoutePaths.profile,
          builder: (_, _) => const ProfileScreen(),
          routes: [
            GoRoute(
              path: 'change-password',
              builder: (_, _) => const ChangePasswordScreen(),
            ),
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
          photoPickerProvider.overrideWithValue(picker),
          avatarRepositoryProvider.overrideWithValue(avatars),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<Map<String, dynamic>> profileDoc() async =>
      (await db.doc(FirestorePaths.user('u1')).get()).data()!;

  group('Profile photo', () {
    testWidgets('pick from gallery → uploaded → saved on profile', (
      tester,
    ) async {
      await pump(tester, session: emailUser);
      picker.next = (
        bytes: Uint8List.fromList([1, 2, 3]),
        contentType: 'image/jpeg',
      );

      await tester.tap(find.byTooltip(AppStrings.changePhoto));
      await tester.pumpAndSettle();
      await tapText(tester, AppStrings.photoFromGallery);

      expect(picker.sources, [PhotoSource.gallery]);
      expect(avatars.files['u1'], [1, 2, 3]);
      expect(
        (await profileDoc())[UserFields.photoUrl],
        'https://storage.test/avatars/u1/avatar.jpg',
      );
      expect(find.text(AppStrings.photoUpdated), findsOneWidget);
    });

    testWidgets('cancelling the picker changes nothing', (tester) async {
      await pump(tester, session: emailUser);
      await tester.tap(find.byTooltip(AppStrings.changePhoto));
      await tester.pumpAndSettle();
      await tapText(tester, AppStrings.photoFromGallery);

      expect(avatars.files, isEmpty);
      expect((await profileDoc()).containsKey(UserFields.photoUrl), isFalse);
    });

    testWidgets('a photo over 2 MB is refused before upload', (tester) async {
      await pump(tester, session: emailUser);
      picker.next = (
        bytes: Uint8List(AvatarRepository.maxBytes),
        contentType: 'image/jpeg',
      );
      await tester.tap(find.byTooltip(AppStrings.changePhoto));
      await tester.pumpAndSettle();
      await tapText(tester, AppStrings.photoFromGallery);

      expect(avatars.files, isEmpty);
      expect(find.text(AppStrings.photoTooLarge), findsOneWidget);
    });

    testWidgets('upload failure shows a friendly message', (tester) async {
      await pump(tester, session: emailUser);
      picker.next = (bytes: Uint8List(10), contentType: 'image/jpeg');
      avatars.nextError = Exception('network');
      await tester.tap(find.byTooltip(AppStrings.changePhoto));
      await tester.pumpAndSettle();
      await tapText(tester, AppStrings.photoFromGallery);

      expect(find.text(AppStrings.photoFailed), findsOneWidget);
    });

    testWidgets('remove photo clears it everywhere', (tester) async {
      await pump(tester, session: emailUser);
      await db.doc(FirestorePaths.user('u1')).update({
        UserFields.photoUrl: 'https://old',
      });
      avatars.files['u1'] = Uint8List(1);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(AppStrings.changePhoto));
      await tester.pumpAndSettle();
      await tapText(tester, AppStrings.photoRemove);

      expect(avatars.files, isEmpty);
      expect((await profileDoc()).containsKey(UserFields.photoUrl), isFalse);
    });
  });

  group('Change password', () {
    testWidgets('only offered to email/password accounts', (tester) async {
      await pump(tester, session: googleUser);
      expect(find.text(AppStrings.changePassword), findsNothing);

      await pump(tester, session: emailUser);
      expect(find.text(AppStrings.changePassword), findsOneWidget);
    });

    testWidgets('validates, changes, and returns to profile', (tester) async {
      await pump(
        tester,
        session: emailUser,
        start: RoutePaths.profileChangePassword,
      );
      Finder field(String label) => find.widgetWithText(TextFormField, label);

      await tester.enterText(field(AppStrings.fieldCurrentPassword), 'old1234');
      await tester.enterText(field(AppStrings.fieldNewPasswordShort), 'short');
      await tester.enterText(field(AppStrings.fieldConfirmPassword), 'short');
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.changePassword),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.validationPasswordShort), findsOneWidget);
      expect(auth.calls, isEmpty);

      await tester.enterText(
        field(AppStrings.fieldNewPasswordShort),
        'notes2027',
      );
      await tester.enterText(
        field(AppStrings.fieldConfirmPassword),
        'notes2027',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.changePassword),
      );
      await tester.pumpAndSettle();

      expect(auth.calls, ['changePassword:old1234->notes2027']);
      expect(find.text(AppStrings.passwordChanged), findsOneWidget);
      expect(find.text('Taiba Shaikh'), findsOneWidget); // back on profile
    });

    testWidgets('wrong current password shows the friendly message', (
      tester,
    ) async {
      await pump(
        tester,
        session: emailUser,
        start: RoutePaths.profileChangePassword,
      );
      auth.nextError = const AuthException(AuthFailure.invalidCredential);
      Finder field(String label) => find.widgetWithText(TextFormField, label);
      await tester.enterText(field(AppStrings.fieldCurrentPassword), 'wrong');
      await tester.enterText(
        field(AppStrings.fieldNewPasswordShort),
        'notes2027',
      );
      await tester.enterText(
        field(AppStrings.fieldConfirmPassword),
        'notes2027',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.changePassword),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.authErrorInvalidCredential), findsOneWidget);
    });
  });

  group('Delete account', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.ensureVisible(find.text(AppStrings.deleteAccount));
      await tapText(tester, AppStrings.deleteAccount);
    }

    testWidgets(
      'email account: needs the password, then deletes and goes home',
      (tester) async {
        await pump(tester, session: emailUser);
        await openDialog(tester);
        expect(find.text(AppStrings.deleteAccountTitle), findsOneWidget);

        await tapText(tester, AppStrings.deleteAccountConfirm);
        expect(
          find.text(AppStrings.validationPasswordRequired),
          findsOneWidget,
        );
        expect(auth.calls, isEmpty);

        await tester.enterText(
          find.widgetWithText(TextFormField, AppStrings.fieldPassword),
          'secret123',
        );
        await tapText(tester, AppStrings.deleteAccountConfirm);

        expect(auth.calls, ['reauth:secret123', 'deleteAccount']);
        expect(find.text('HOME'), findsOneWidget);
        expect(find.text(AppStrings.accountDeleted), findsOneWidget);
      },
    );

    testWidgets('Google account: no password field, re-confirms with Google', (
      tester,
    ) async {
      await pump(tester, session: googleUser);
      await openDialog(tester);
      expect(find.text(AppStrings.deleteAccountGoogleHint), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, AppStrings.fieldPassword),
        findsNothing,
      );
      await tapText(tester, AppStrings.deleteAccountConfirm);
      expect(auth.calls, ['reauth:google', 'deleteAccount']);
    });

    testWidgets('cancel deletes nothing', (tester) async {
      await pump(tester, session: googleUser);
      await openDialog(tester);
      await tapText(tester, AppStrings.cancel);
      expect(auth.calls, isEmpty);
      expect(find.text('Taiba Shaikh'), findsOneWidget);
    });

    testWidgets('wrong password keeps the dialog open with a message', (
      tester,
    ) async {
      await pump(tester, session: emailUser);
      await openDialog(tester);
      auth.nextError = const AuthException(AuthFailure.invalidCredential);
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.fieldPassword),
        'wrong',
      );
      await tapText(tester, AppStrings.deleteAccountConfirm);

      expect(find.text(AppStrings.authErrorInvalidCredential), findsOneWidget);
      expect(find.text(AppStrings.deleteAccountTitle), findsOneWidget);
      expect(auth.calls, isNot(contains('deleteAccount')));
    });
  });
}
