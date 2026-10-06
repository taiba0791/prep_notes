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
import 'package:prepnotes/core/services/file_download.dart';
import 'package:prepnotes/core/theme/app_theme.dart';
import 'package:prepnotes/data/models/admin_stats.dart';
import 'package:prepnotes/data/models/purchase.dart';
import 'package:prepnotes/data/repositories/admin_repository.dart';
import 'package:prepnotes/features/admin/domain/orders_csv.dart';
import 'package:prepnotes/features/admin/presentation/admin_dashboard_page.dart';
import 'package:prepnotes/features/admin/presentation/admin_ops_controllers.dart';
import 'package:prepnotes/features/admin/presentation/admin_scaffold.dart';
import 'package:prepnotes/features/admin/presentation/orders_admin_pages.dart';
import 'package:prepnotes/features/admin/presentation/users_admin_pages.dart';
import 'package:prepnotes/features/auth/data/auth_repository.dart';
import 'package:prepnotes/features/auth/domain/auth_session.dart';

import '../../fakes/fake_auth_repository.dart';

/// Real Firestore reads (on a fake database); actions are recorded.
class RecordingAdminRepository extends FirebaseAdminRepository {
  RecordingAdminRepository(super.db)
    : super(functions: () => throw StateError('no functions in tests'));

  final calls = <String>[];
  String? failWith;

  Future<void> _record(String call) async {
    calls.add(call);
    if (failWith != null) throw AdminActionException(failWith!);
  }

  @override
  Future<void> recomputeStats() => _record('recompute');

  @override
  Future<void> setUserDisabled(String uid, {required bool disabled}) =>
      _record('disable:$uid:$disabled');

  @override
  Future<void> setAdmin(String email, {required bool admin}) =>
      _record('admin:$email:$admin');

  @override
  Future<void> markOrderRefunded(String orderId, {String reason = ''}) =>
      _record('refund:$orderId:$reason');
}

class FakeDownloader implements FileDownloader {
  FakeDownloader({this.isSupported = true});

  @override
  final bool isSupported;
  final saved = <String, String>{};

  @override
  void saveText(String fileName, String content, {String mimeType = ''}) =>
      saved[fileName] = content;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeFirebaseFirestore db;
  late RecordingAdminRepository repo;
  late FakeDownloader downloader;

  Future<void> seedUser(
    String uid,
    String name, {
    bool disabled = false,
    String role = UserRole.student,
    int t = 1,
  }) => db.doc(FirestorePaths.user(uid)).set({
    UserFields.name: name,
    UserFields.nameLower: name.toLowerCase(),
    UserFields.email: '$uid@example.com',
    UserFields.role: role,
    UserFields.totalStudyMinutes: 125,
    UserFields.createdAt: Timestamp.fromMillisecondsSinceEpoch(t * 1000),
    UserFields.disabled: disabled,
  });

  Future<void> seedOrder(
    String id, {
    String status = OrderStatus.paid,
    String uid = 'alice',
    int amount = 14900,
    DateTime? at,
  }) => db.doc(FirestorePaths.order(id)).set({
    OrderFields.userId: uid,
    OrderFields.noteIds: ['n1'],
    OrderFields.noteTitles: ['Data Structures'],
    OrderFields.amount: amount,
    OrderFields.status: status,
    OrderFields.createdAt: Timestamp.fromDate(at ?? DateTime(2026, 10, 5)),
    if (status == OrderStatus.paid) ...{
      OrderFields.paidAt: Timestamp.fromDate(at ?? DateTime(2026, 10, 5)),
      OrderFields.razorpayPaymentId: 'pay_$id',
    },
  });

  Future<void> pump(
    WidgetTester tester,
    String start, {
    double width = 1400,
  }) async {
    tester.view.physicalSize = Size(width, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: start,
      routes: [
        ShellRoute(
          builder: (_, state, child) =>
              AdminScaffold(currentPath: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: RoutePaths.admin,
              builder: (_, _) => const AdminDashboardPage(),
              routes: [
                GoRoute(
                  path: 'users',
                  builder: (_, _) => const AdminUsersPage(),
                  routes: [
                    GoRoute(
                      path: ':uid',
                      builder: (_, s) =>
                          AdminUserPage(uid: s.pathParameters['uid']!),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'orders',
                  builder: (_, _) => const AdminOrdersPage(),
                  routes: [
                    GoRoute(
                      path: ':id',
                      builder: (_, s) =>
                          AdminOrderPage(orderId: s.pathParameters['id']!),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'notes/:id/edit',
                  builder: (_, s) => Text('edit:${s.pathParameters['id']}'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(db),
          adminRepositoryProvider.overrideWithValue(repo),
          fileDownloaderProvider.overrideWithValue(downloader),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(const AuthSession(uid: 'boss', isAdmin: true)),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = RecordingAdminRepository(db);
    downloader = FakeDownloader();
  });

  group('pure helpers', () {
    test('CSV: header, rupees, quoting and formula protection', () {
      final csv = ordersToCsv([
        PurchaseOrder(
          id: 'order_1',
          userId: 'alice',
          noteTitles: const ['Maths, Part "1"', 'DS'],
          amount: 14950,
          status: OrderStatus.paid,
          createdAt: DateTime.utc(2026, 10, 6),
        ),
        const PurchaseOrder(
          id: 'order_2',
          userId: 'bob',
          amount: 4900,
          status: OrderStatus.failed,
          failureReason: '=HYPERLINK("x")',
        ),
      ]);
      final lines = csv.trimRight().split('\r\n');
      expect(lines.first, startsWith('order_id,created_at,paid_at,status'));
      expect(lines[1], contains('"Maths, Part ""1"" | DS"'));
      expect(lines[1], contains(',149.50,'));
      expect(lines[1], contains('2026-10-06T00:00:00.000Z'));
      expect(lines[2], contains('"\'=HYPERLINK(""x"")"'));
      expect(lines, hasLength(3));
    });

    test('fillDays: 30 days, oldest first, gaps are zero', () {
      final days = fillDays(
        const [DailyStat(date: '2026-10-05', revenue: 4900)],
        DateTime(2026, 10, 6),
        30,
      );
      expect(days, hasLength(30));
      expect(days.first.date, '2026-09-07');
      expect(days.last.date, '2026-10-06');
      expect(days[28].revenue, 4900);
      expect(days.last.revenue, 0);
    });
  });

  group('repository reads', () {
    test('users: newest first; email and name prefix search', () async {
      await seedUser('alice', 'Alice Rao', t: 1);
      await seedUser('bob', 'Bob Shah', t: 2, disabled: true);
      final all = await repo.users();
      expect(all.items.map((u) => u.uid), ['bob', 'alice']);
      expect(all.items.first.disabled, isTrue);
      expect((await repo.users(search: 'ALI')).items.single.uid, 'alice');
      expect((await repo.users(search: 'bob@ex')).items.single.uid, 'bob');
      expect((await repo.users(search: 'zz')).items, isEmpty);
    });

    test('orders: status and date filters', () async {
      await seedOrder('o1', at: DateTime(2026, 10, 1));
      await seedOrder(
        'o2',
        status: OrderStatus.failed,
        at: DateTime(2026, 10, 3),
      );
      await seedOrder('o3', at: DateTime(2026, 10, 5, 23, 30));
      expect((await repo.orders(const OrderFilter())).items.map((o) => o.id), [
        'o3',
        'o2',
        'o1',
      ]);
      expect(
        (await repo.orders(const OrderFilter(status: OrderStatus.paid))).items
            .map((o) => o.id),
        ['o3', 'o1'],
      );
      final range = OrderFilter(
        from: DateTime(2026, 10, 2),
        to: DateTime(2026, 10, 5),
      );
      expect((await repo.orders(range)).items.map((o) => o.id), ['o3', 'o2']);
    });

    test('stats: defaults when empty, daily oldest first', () async {
      expect(await repo.globalStats(), const GlobalStats());
      for (final d in ['2026-10-04', '2026-10-06', '2026-10-05']) {
        await db.doc(FirestorePaths.statsDay(d)).set({
          DailyStatsFields.date: d,
          DailyStatsFields.revenue: 100,
        });
      }
      expect((await repo.dailyStats()).map((d) => d.date), [
        '2026-10-04',
        '2026-10-05',
        '2026-10-06',
      ]);
    });
  });

  group('Dashboard', () {
    for (final width in [400.0, 1400.0]) {
      testWidgets('live numbers, chart, top notes, recent sales ($width)', (
        tester,
      ) async {
        await db.doc(FirestorePaths.statsGlobal).set({
          StatsFields.totalStudents: 12,
          StatsFields.totalNotes: 5,
          StatsFields.totalPurchases: 3,
          StatsFields.totalRevenue: 44700,
        });
        await db.doc(FirestorePaths.note('n1')).set({
          NoteFields.title: 'Data Structures',
          NoteFields.universityId: 'mu',
          NoteFields.semesterId: 's3',
          NoteFields.subjectId: 'ds',
          NoteFields.moduleId: 'm1',
          NoteFields.price: 14900,
          NoteFields.isPublished: true,
          NoteFields.purchaseCount: 3,
        });
        await seedOrder('o1', at: DateTime.now());
        await pump(tester, RoutePaths.admin, width: width);

        expect(find.text('12'), findsOneWidget);
        expect(find.text('₹447'), findsOneWidget);
        expect(find.text(AppStrings.revenueLast30), findsOneWidget);
        expect(find.text(AppStrings.soldCount(3)), findsOneWidget);
        expect(find.text(AppStrings.feedbackComingSoon), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.text(AppStrings.recalculateStats));
        await tester.tap(find.text(AppStrings.recalculateStats));
        await tester.pumpAndSettle();
        expect(repo.calls, ['recompute']);
        expect(find.text(AppStrings.statsRecalculated), findsOneWidget);
      });
    }

    testWidgets('empty: zeros and "No sales yet"', (tester) async {
      await pump(tester, RoutePaths.admin);
      expect(find.text('₹0'), findsWidgets);
      expect(find.text(AppStrings.noSalesYet), findsNWidgets(2));
    });
  });

  group('Users', () {
    for (final width in [400.0, 1400.0]) {
      testWidgets('list, search, open details ($width)', (tester) async {
        await seedUser('alice', 'Alice Rao', t: 1);
        await seedUser('bob', 'Bob Shah', t: 2, disabled: true);
        await pump(tester, RoutePaths.adminUsers, width: width);
        expect(find.text('Alice Rao'), findsOneWidget);
        expect(find.text('Bob Shah'), findsOneWidget);
        // Table chip on desktop, in the subtitle on phones.
        expect(find.textContaining(AppStrings.userDisabled), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'bob');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(find.text('Alice Rao'), findsNothing);

        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pumpAndSettle();
        expect(find.text('bob@example.com'), findsOneWidget);
        expect(find.textContaining('2 h 5 min'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('disable needs confirming; enable does not', (tester) async {
      await seedUser('alice', 'Alice Rao');
      await pump(tester, RoutePaths.adminUser('alice'));
      await tester.tap(find.text(AppStrings.disableAccount));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.disableConfirmTitle), findsOneWidget);
      await tester.tap(find.text(AppStrings.disableAccount).last);
      await tester.pumpAndSettle();
      expect(repo.calls, ['disable:alice:true']);
      expect(find.text(AppStrings.accountDisabled), findsOneWidget);
    });

    testWidgets('make admin uses the email; errors are shown', (tester) async {
      await seedUser('alice', 'Alice Rao');
      repo.failWith = 'Admins only.';
      await pump(tester, RoutePaths.adminUser('alice'));
      await tester.tap(find.text(AppStrings.makeAdmin));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.makeAdmin).last);
      await tester.pumpAndSettle();
      expect(repo.calls, ['admin:alice@example.com:true']);
      expect(find.text('Admins only.'), findsOneWidget);
    });

    testWidgets('no disable / admin buttons on my own account', (tester) async {
      await seedUser('boss', 'The Boss', role: UserRole.admin);
      await pump(tester, RoutePaths.adminUser('boss'));
      expect(find.text(AppStrings.disableAccount), findsNothing);
      expect(find.text(AppStrings.removeAdmin), findsNothing);
      expect(find.widgetWithText(Chip, AppStrings.roleAdmin), findsOneWidget);
    });

    testWidgets('missing user', (tester) async {
      await pump(tester, RoutePaths.adminUser('ghost'));
      expect(find.text(AppStrings.userNotFound), findsOneWidget);
    });
  });

  group('Orders', () {
    for (final width in [400.0, 1400.0]) {
      testWidgets('list, filter by status, export CSV ($width)', (
        tester,
      ) async {
        await seedOrder('o1');
        await seedOrder('o2', status: OrderStatus.failed);
        await pump(tester, RoutePaths.adminOrders, width: width);
        expect(
          find.byType(OrderStatusChip),
          findsNWidgets(width > 600 ? 2 : 0),
        );
        expect(find.textContaining(AppStrings.orderStatusFailed), findsWidgets);

        await tester.tap(find.byType(DropdownButtonFormField<String?>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppStrings.orderStatusPaid).last);
        await tester.pumpAndSettle();
        expect(find.textContaining(AppStrings.orderStatusFailed), findsNothing);

        await tester.tap(find.text(AppStrings.exportCsv));
        await tester.pumpAndSettle();
        final file = downloader.saved.values.single;
        expect(file, contains('o1'));
        expect(file, isNot(contains('o2')));
        expect(find.text(AppStrings.exported(1)), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('export on the phone app explains it is website-only', (
      tester,
    ) async {
      downloader = FakeDownloader(isSupported: false);
      await seedOrder('o1');
      await pump(tester, RoutePaths.adminOrders);
      await tester.tap(find.text(AppStrings.exportCsv));
      await tester.pump();
      expect(find.text(AppStrings.exportWebOnly), findsOneWidget);
    });

    testWidgets('detail + record a refund with a reason', (tester) async {
      await seedOrder('o1');
      await pump(tester, RoutePaths.adminOrder('o1'));
      expect(find.text('pay_o1'), findsOneWidget);
      expect(find.text('₹149'), findsOneWidget);

      await tester.tap(find.text(AppStrings.markRefunded));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.refundDialogMessage), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Wrong subject');
      await tester.tap(find.text(AppStrings.markRefunded).last);
      await tester.pumpAndSettle();
      expect(repo.calls, ['refund:o1:Wrong subject']);
      expect(find.text(AppStrings.refundRecorded), findsOneWidget);
    });

    testWidgets('no refund button unless paid', (tester) async {
      await seedOrder('o1', status: OrderStatus.failed);
      await pump(tester, RoutePaths.adminOrder('o1'));
      expect(find.text(AppStrings.markRefunded), findsNothing);
    });
  });
}
