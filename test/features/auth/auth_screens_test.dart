import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prepnotes/core/constants/app_strings.dart';
import 'package:prepnotes/core/constants/firestore_paths.dart';
import 'package:prepnotes/core/theme/app_theme.dart';
import 'package:prepnotes/data/repositories/user_repository.dart';
import 'package:prepnotes/features/auth/data/auth_repository.dart';
import 'package:prepnotes/features/auth/domain/auth_failure.dart';
import 'package:prepnotes/features/auth/presentation/forgot_password_screen.dart';
import 'package:prepnotes/features/auth/presentation/login_screen.dart';
import 'package:prepnotes/features/auth/presentation/register_screen.dart';

import '../../fakes/fake_auth_repository.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeAuthRepository auth;
  late FakeFirebaseFirestore db;

  Future<void> pump(WidgetTester tester, Widget screen, {double? width}) async {
    if (width != null) {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    auth = FakeAuthRepository();
    db = FakeFirebaseFirestore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(FirestoreUserRepository(db)),
        ],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FilledButton, label));
    await tester.pumpAndSettle();
  }

  group('Login', () {
    testWidgets('empty form shows errors and does not call Firebase', (
      tester,
    ) async {
      await pump(tester, const LoginScreen());
      await tapButton(tester, AppStrings.loginButton);

      expect(find.text(AppStrings.validationEmailRequired), findsOneWidget);
      expect(find.text(AppStrings.validationPasswordRequired), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('valid login signs in and creates the missing profile', (
      tester,
    ) async {
      await pump(tester, const LoginScreen());
      await tester.enterText(field(AppStrings.fieldEmail), 'taiba@x.com');
      await tester.enterText(field(AppStrings.fieldPassword), 'whatever');
      await tapButton(tester, AppStrings.loginButton);

      expect(auth.calls, ['signIn:taiba@x.com']);
      final profile = await db
          .doc(FirestorePaths.user('uid-taiba@x.com'))
          .get();
      expect(profile.data()![UserFields.name], 'taiba');
    });

    testWidgets('wrong password shows the friendly message', (tester) async {
      await pump(tester, const LoginScreen());
      auth.nextError = const AuthException(AuthFailure.invalidCredential);
      await tester.enterText(field(AppStrings.fieldEmail), 'taiba@x.com');
      await tester.enterText(field(AppStrings.fieldPassword), 'nope');
      await tapButton(tester, AppStrings.loginButton);

      expect(find.text(AppStrings.authErrorInvalidCredential), findsOneWidget);
    });

    testWidgets('show / hide password', (tester) async {
      await pump(tester, const LoginScreen());
      EditableText editable() => tester.widget<EditableText>(
        find.descendant(
          of: field(AppStrings.fieldPassword),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable().obscureText, isTrue);
      await tester.tap(find.byTooltip(AppStrings.showPassword));
      await tester.pump();
      expect(editable().obscureText, isFalse);
    });

    testWidgets('card on tablet/desktop, no card on mobile', (tester) async {
      await pump(tester, const LoginScreen(), width: 1200);
      expect(find.byType(Card), findsOneWidget);

      await pump(tester, const LoginScreen(), width: 400);
      expect(find.byType(Card), findsNothing);
    });
  });

  group('Register', () {
    Future<void> fill(
      WidgetTester tester, {
      String name = 'Taiba Shaikh',
      String email = 'taiba@x.com',
      String password = 'notes2026',
      String? confirm,
    }) async {
      await tester.enterText(field(AppStrings.fieldName), name);
      await tester.enterText(field(AppStrings.fieldEmail), email);
      await tester.enterText(field(AppStrings.fieldNewPassword), password);
      await tester.enterText(
        field(AppStrings.fieldConfirmPassword),
        confirm ?? password,
      );
    }

    testWidgets('weak and mismatched passwords are caught', (tester) async {
      await pump(tester, const RegisterScreen(), width: 1200);
      await fill(tester, password: 'abcdefgh', confirm: 'different');
      await tapButton(tester, AppStrings.registerButton);

      expect(find.text(AppStrings.validationPasswordWeak), findsOneWidget);
      expect(find.text(AppStrings.validationPasswordMismatch), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('creates account, student profile and sends verification', (
      tester,
    ) async {
      await pump(tester, const RegisterScreen(), width: 1200);
      await fill(tester);
      await tapButton(tester, AppStrings.registerButton);

      expect(auth.calls, ['register:taiba@x.com', 'verify']);
      final data = (await db.doc(FirestorePaths.user('new-uid')).get()).data()!;
      expect(data[UserFields.name], 'Taiba Shaikh');
      expect(data[UserFields.role], UserRole.student);
    });

    testWidgets('email already in use shows the friendly message', (
      tester,
    ) async {
      await pump(tester, const RegisterScreen(), width: 1200);
      auth.nextError = const AuthException(AuthFailure.emailAlreadyInUse);
      await fill(tester);
      await tapButton(tester, AppStrings.registerButton);

      expect(find.text(AppStrings.authErrorEmailInUse), findsOneWidget);
    });
  });

  group('Forgot password', () {
    testWidgets('sends the link and shows the confirmation', (tester) async {
      await pump(tester, const ForgotPasswordScreen());
      await tester.enterText(field(AppStrings.fieldEmail), 'taiba@x.com');
      await tapButton(tester, AppStrings.forgotButton);

      expect(auth.calls, ['reset:taiba@x.com']);
      expect(find.text(AppStrings.forgotSentTitle), findsOneWidget);
    });

    testWidgets('invalid email is caught before sending', (tester) async {
      await pump(tester, const ForgotPasswordScreen());
      await tester.enterText(field(AppStrings.fieldEmail), 'not-an-email');
      await tapButton(tester, AppStrings.forgotButton);

      expect(find.text(AppStrings.validationEmailInvalid), findsOneWidget);
      expect(auth.calls, isEmpty);
    });
  });
}
