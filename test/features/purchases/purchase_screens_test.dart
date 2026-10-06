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
import 'package:prepnotes/data/models/purchase.dart';
import 'package:prepnotes/data/repositories/purchases_repository.dart';
import 'package:prepnotes/features/auth/data/auth_repository.dart';
import 'package:prepnotes/features/auth/domain/auth_session.dart';
import 'package:prepnotes/features/purchases/data/payment_service.dart';
import 'package:prepnotes/features/purchases/domain/purchase_failure.dart';
import 'package:prepnotes/features/purchases/presentation/checkout_screen.dart';
import 'package:prepnotes/features/purchases/presentation/my_purchases_screen.dart';
import 'package:prepnotes/features/purchases/presentation/note_viewer_screen.dart';
import 'package:prepnotes/features/purchases/presentation/purchases_controllers.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_purchases.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeFirebaseFirestore db;
  late FakePurchasesRepository repo;
  late FakePaymentService payments;

  Future<void> addNote(String id, {int price = 14900}) =>
      db.doc(FirestorePaths.note(id)).set({
        NoteFields.title: 'Data Structures',
        NoteFields.universityId: 'mu',
        NoteFields.semesterId: 's3',
        NoteFields.subjectId: 'ds',
        NoteFields.moduleId: 'm1',
        NoteFields.subjectName: 'DS',
        NoteFields.price: price,
        NoteFields.isFree: price == 0,
        NoteFields.isPublished: true,
        NoteFields.updatedAt: Timestamp.now(),
      });

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
          path: '/checkout/:id',
          builder: (_, s) => CheckoutScreen(
            target: CheckoutTarget(CheckoutKind.note, s.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: RoutePaths.purchases,
          builder: (_, _) => const MyPurchasesScreen(),
        ),
        GoRoute(
          path: '/notes/:id',
          builder: (_, s) => Text('note:${s.pathParameters['id']}'),
          routes: [
            // pdfx can't render in desktop tests: stand-in for the viewer.
            GoRoute(
              path: 'view',
              builder: (_, s) => Text('viewer:${s.pathParameters['id']}'),
            ),
          ],
        ),
        GoRoute(
          path: '/real-viewer/:id',
          builder: (_, s) => NoteViewerScreen(noteId: s.pathParameters['id']!),
        ),
        GoRoute(path: RoutePaths.notes, builder: (_, _) => const Text('notes')),
        GoRoute(
          path: RoutePaths.refundPolicy,
          builder: (_, _) => const Text('refund'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(db),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(
              const AuthSession(uid: 'alice', email: 'alice@example.com'),
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

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FakePurchasesRepository();
    payments = FakePaymentService();
  });

  group('Checkout', () {
    for (final width in [400.0, 1200.0]) {
      testWidgets('pay → success → Read now (width $width)', (tester) async {
        await addNote('n1');
        await pump(tester, RoutePaths.checkout('n1'), width: width);
        expect(find.text('Pay ₹149'), findsOneWidget);
        expect(find.text(AppStrings.securePayment), findsOneWidget);

        await tester.tap(find.text('Pay ₹149'));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.paymentSuccessTitle), findsOneWidget);
        expect(repo.calls, contains('verify:order_1:pay_1:sig'));

        await tester.tap(find.text(AppStrings.readNow));
        await tester.pumpAndSettle();
        expect(find.text('viewer:n1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('cancelled → message + Try again', (tester) async {
      await addNote('n1');
      payments.outcome = const PaymentDismissed();
      await pump(tester, RoutePaths.checkout('n1'));
      await tester.tap(find.text('Pay ₹149'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.paymentCancelled), findsOneWidget);
      expect(find.text(AppStrings.retry), findsOneWidget);
    });

    testWidgets('already owned → straight to success', (tester) async {
      await addNote('n1');
      await db.doc(FirestorePaths.entitlement('alice', 'n1')).set({
        EntitlementFields.noteId: 'n1',
        EntitlementFields.expiresAt: Timestamp.fromDate(DateTime(2099)),
      });
      await pump(tester, RoutePaths.checkout('n1'));
      expect(find.text(AppStrings.readNow), findsOneWidget);
      expect(find.text('Pay ₹149'), findsNothing);
    });

    testWidgets('free or missing note → not available', (tester) async {
      await addNote('f1', price: 0);
      await pump(tester, RoutePaths.checkout('f1'));
      expect(find.text(AppStrings.payErrNotAvailable), findsOneWidget);
    });

    testWidgets('phone app → Buy on website, no Pay button', (tester) async {
      await addNote('n1');
      await pump(
        tester,
        RoutePaths.checkout('n1'),
        width: 400,
        buyInApp: false,
      );
      expect(find.text(AppStrings.buyOnWebsite), findsOneWidget);
      expect(find.text('Pay ₹149'), findsNothing);
    });
  });

  group('My Purchases', () {
    testWidgets('empty states on both tabs', (tester) async {
      await pump(tester, RoutePaths.purchases);
      expect(find.text(AppStrings.noPurchasesTitle), findsOneWidget);
      await tester.tap(find.text(AppStrings.purchasesOrdersTab));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.noOrdersTitle), findsOneWidget);
    });

    for (final width in [400.0, 1200.0]) {
      testWidgets('notes with search, and orders (width $width)', (
        tester,
      ) async {
        repo.owned = [
          Purchase(
            noteId: 'n1',
            title: 'Data Structures',
            subjectName: 'DS',
            purchasedAt: DateTime(2026, 10, 6),
            expiresAt: DateTime(2099, 4, 6),
          ),
          // Expired → "Buy again".
          Purchase(
            noteId: 'n2',
            title: 'Operating Systems',
            expiresAt: DateTime(2020, 1, 1),
          ),
        ];
        repo.orderList = [
          PurchaseOrder(
            id: 'order_1',
            userId: 'alice',
            noteTitles: const ['Data Structures'],
            amount: 14900,
            status: OrderStatus.paid,
            createdAt: DateTime(2026, 10, 6),
          ),
          const PurchaseOrder(
            id: 'order_2',
            userId: 'alice',
            noteTitles: ['Operating Systems'],
            amount: 9900,
            status: OrderStatus.failed,
            failureReason: 'Card declined',
          ),
        ];
        await pump(tester, RoutePaths.purchases, width: width);
        expect(find.text('Data Structures'), findsOneWidget);
        expect(find.text('Operating Systems'), findsOneWidget);
        expect(find.textContaining('Access until 6 Apr 2099'), findsOneWidget);
        expect(find.text(AppStrings.buyAgain), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'operating');
        await tester.pumpAndSettle();
        expect(find.text('Data Structures'), findsNothing);
        expect(find.text('Operating Systems'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.noMatches), findsOneWidget);

        await tester.tap(find.text(AppStrings.purchasesOrdersTab));
        await tester.pumpAndSettle();
        expect(find.text('₹149'), findsOneWidget);
        expect(find.text(AppStrings.orderStatusPaid), findsOneWidget);
        expect(find.text(AppStrings.orderStatusFailed), findsOneWidget);
        expect(find.textContaining('Card declined'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Viewer', () {
    testWidgets('not bought → lock + Buy now back to the note', (tester) async {
      repo.fileFails = PurchaseFailure.notPurchased;
      await pump(tester, '/real-viewer/n1');
      expect(find.text(AppStrings.payErrNotPurchased), findsOneWidget);
      await tester.tap(find.text(AppStrings.buyNow));
      await tester.pumpAndSettle();
      expect(find.text('note:n1'), findsOneWidget);
    });

    testWidgets('server busy → error with retry', (tester) async {
      repo.fileFails = PurchaseFailure.busy;
      await pump(tester, '/real-viewer/n1');
      expect(find.text(AppStrings.payErrBusy), findsOneWidget);
      repo.fileFails = null;
      await tester.tap(find.text(AppStrings.retry));
      await tester.pump();
      expect(repo.calls.where((c) => c == 'fileUrl:n1'), hasLength(2));
    });
  });
}
