import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prepnotes/core/constants/app_strings.dart';
import 'package:prepnotes/core/constants/firestore_paths.dart';
import 'package:prepnotes/core/providers/firebase_providers.dart';
import 'package:prepnotes/core/router/route_paths.dart';
import 'package:prepnotes/core/theme/app_theme.dart';
import 'package:prepnotes/data/models/access.dart';
import 'package:prepnotes/data/models/catalog.dart';
import 'package:prepnotes/data/repositories/purchases_repository.dart';
import 'package:prepnotes/features/auth/data/auth_repository.dart';
import 'package:prepnotes/features/auth/domain/auth_session.dart';
import 'package:prepnotes/features/purchases/data/payment_service.dart';
import 'package:prepnotes/features/purchases/presentation/bundle_card.dart';
import 'package:prepnotes/features/purchases/presentation/checkout_screen.dart';
import 'package:prepnotes/features/purchases/presentation/my_purchases_screen.dart';
import 'package:prepnotes/features/purchases/presentation/purchases_controllers.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_purchases.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeFirebaseFirestore db;
  late FakePurchasesRepository repo;
  late FakePaymentService payments;

  Future<void> seed() async {
    await db.doc(FirestorePaths.university('mu')).set({
      UniversityFields.name: 'University of Mumbai',
      UniversityFields.isActive: true,
      UniversityFields.order: 1,
    });
    await db.doc(FirestorePaths.semester('s3')).set({
      SemesterFields.universityId: 'mu',
      SemesterFields.number: 3,
      SemesterFields.name: 'Semester 3',
      SemesterFields.isActive: true,
    });
    for (final id in ['n1', 'n2']) {
      await db.doc(FirestorePaths.note(id)).set({
        NoteFields.title: 'Note $id',
        NoteFields.universityId: 'mu',
        NoteFields.semesterId: 's3',
        NoteFields.subjectId: 'ds',
        NoteFields.moduleId: 'm1',
        NoteFields.price: 4900,
        NoteFields.isPublished: true,
      });
    }
  }

  Future<void> pump(
    WidgetTester tester,
    String start, {
    double width = 1200,
    bool buyInApp = true,
  }) async {
    tester.view.physicalSize = Size(width, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: start,
      routes: [
        GoRoute(
          path: '/checkout/bundle/:id',
          builder: (_, s) => CheckoutScreen(
            target: CheckoutTarget(
              CheckoutKind.bundle,
              s.pathParameters['id']!,
            ),
          ),
        ),
        GoRoute(
          path: '/checkout/room/:id',
          builder: (_, s) => CheckoutScreen(
            target: CheckoutTarget(CheckoutKind.room, s.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/card',
          builder: (_, _) => const Scaffold(
            body: SemesterBundleCard(
              semester: Semester(
                id: 's3',
                universityId: 'mu',
                number: 3,
                name: 'Semester 3',
              ),
            ),
          ),
        ),
        GoRoute(
          path: RoutePaths.purchases,
          builder: (_, _) => const MyPurchasesScreen(),
        ),
        GoRoute(
          path: '/notes/s/:id',
          builder: (_, s) => Text('semester:${s.pathParameters['id']}'),
        ),
        for (final p in [RoutePaths.resources, RoutePaths.notes])
          GoRoute(path: p, builder: (_, _) => Text('page:$p')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(db),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(
              const AuthSession(uid: 'alice', email: 'alice@x.com'),
            ),
          ),
          purchasesRepositoryProvider.overrideWithValue(repo),
          paymentServiceProvider.overrideWithValue(payments),
          buyInAppProvider.overrideWithValue(buyInApp),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = FakePurchasesRepository();
    payments = FakePaymentService();
    await seed();
  });

  group('Semester bundle card', () {
    for (final width in [400.0, 1200.0]) {
      testWidgets('offer with real note count and price ($width)', (
        tester,
      ) async {
        await pump(tester, '/card', width: width);
        expect(find.text(AppStrings.bundleTitle), findsOneWidget);
        expect(find.text(AppStrings.bundleNotes(2)), findsOneWidget);
        expect(find.text(AppStrings.bundleRoom), findsOneWidget);
        expect(find.text('₹899'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('active bundle shows its end date', (tester) async {
      repo.bundleList = [
        SemesterBundle(semesterId: 's3', expiresAt: DateTime(2099, 4, 7)),
      ];
      await pump(tester, '/card');
      expect(find.text(AppStrings.bundleActive('7 Apr 2099')), findsOneWidget);
      expect(find.textContaining(AppStrings.buyBundle), findsNothing);
    });

    testWidgets('phone app: Buy on website', (tester) async {
      await pump(tester, '/card', width: 400, buyInApp: false);
      expect(find.text(AppStrings.buyOnWebsite), findsOneWidget);
    });
  });

  group('Checkout', () {
    testWidgets('bundle: summary, pay, verify, then Resource Room button', (
      tester,
    ) async {
      await pump(tester, RoutePaths.checkoutBundle('s3'));
      expect(find.text(AppStrings.semesterBundleName(3)), findsOneWidget);
      expect(find.text('University of Mumbai'), findsOneWidget);
      expect(find.text(AppStrings.bundleNotes(2)), findsOneWidget);

      await tester.tap(find.text('Pay ₹899'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['createBundle:s3', 'verify:order_1:pay_1:sig']);
      expect(find.text(AppStrings.paymentSuccessTitle), findsOneWidget);
      await tester.tap(find.text(AppStrings.roomTitle));
      await tester.pumpAndSettle();
      expect(find.text('page:${RoutePaths.resources}'), findsOneWidget);
    });

    testWidgets('Room plan: subscribe with auto-renew terms', (tester) async {
      await pump(tester, RoutePaths.checkoutRoom('m3'));
      expect(find.text('₹399'), findsOneWidget);
      expect(find.text(AppStrings.perMonths(3)), findsOneWidget);
      expect(find.text(AppStrings.checkoutAutoRenewTerms), findsOneWidget);

      await tester.tap(find.text('${AppStrings.subscribe} · ₹399'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['createSub:m3', 'verifySub:sub_1:pay_s1:sig']);
      expect(payments.subscribed.single.subscriptionId, 'sub_1');
      expect(find.text(AppStrings.paymentSuccessTitle), findsOneWidget);
    });

    testWidgets('already subscribed → no second subscription', (tester) async {
      repo.subscription = const RoomSubscription(
        id: 'sub_1',
        userId: 'alice',
        status: 'active',
      );
      await pump(tester, RoutePaths.checkoutRoom('m1'));
      expect(find.text(AppStrings.paymentSuccessTitle), findsOneWidget);
      expect(find.textContaining(AppStrings.subscribe), findsNothing);
    });

    testWidgets('unknown plan or semester → not available', (tester) async {
      await pump(tester, RoutePaths.checkoutRoom('m99'));
      expect(find.text(AppStrings.payErrNotAvailable), findsOneWidget);
    });
  });

  group('My Purchases → Bundles & Room', () {
    Future<void> openTab(WidgetTester tester, {double width = 1200}) async {
      await pump(tester, RoutePaths.purchases, width: width);
      await tester.tap(find.text(AppStrings.purchasesBundlesTab));
      await tester.pumpAndSettle();
    }

    testWidgets('empty', (tester) async {
      await openTab(tester);
      expect(find.text(AppStrings.noBundlesTitle), findsOneWidget);
    });

    for (final width in [400.0, 1200.0]) {
      testWidgets('bundles + subscription, cancel auto-renew ($width)', (
        tester,
      ) async {
        repo.bundleList = [
          SemesterBundle(
            semesterId: 's3',
            semesterNumber: 3,
            universityName: 'University of Mumbai',
            expiresAt: DateTime(2099, 4, 7),
          ),
          SemesterBundle(
            semesterId: 's2',
            semesterNumber: 2,
            expiresAt: DateTime(2020, 1, 1),
          ),
        ];
        repo.subscription = RoomSubscription(
          id: 'sub_1',
          userId: 'alice',
          planKey: 'm1',
          amount: 14900,
          status: 'active',
          currentEnd: DateTime(2099, 11, 7),
        );
        await openTab(tester, width: width);
        expect(find.text(AppStrings.semesterBundleName(3)), findsOneWidget);
        expect(find.textContaining('Access until 7 Apr 2099'), findsOneWidget);
        expect(find.textContaining('Expired 1 Jan 2020'), findsOneWidget);
        expect(find.text(AppStrings.renewsOn('7 Nov 2099')), findsOneWidget);

        await tester.tap(find.text(AppStrings.cancelAutoRenew));
        await tester.pumpAndSettle();
        expect(
          find.text(AppStrings.cancelAutoRenewMessage('7 Nov 2099')),
          findsOneWidget,
        );
        await tester.tap(find.text(AppStrings.cancelAutoRenew).last);
        await tester.pumpAndSettle();
        expect(repo.calls, contains('cancelSub'));
        expect(find.text(AppStrings.autoRenewCancelled), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  test('CheckoutTarget keys round-trip', () {
    for (final t in const [
      CheckoutTarget(CheckoutKind.note, 'n1'),
      CheckoutTarget(CheckoutKind.bundle, 's3'),
      CheckoutTarget(CheckoutKind.room, 'm6'),
    ]) {
      final back = CheckoutTarget.parse(t.key);
      expect((back.kind, back.id), (t.kind, t.id));
    }
    expect(Timestamp.now(), isNotNull);
  });
}
