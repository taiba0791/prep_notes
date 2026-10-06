import 'dart:typed_data';

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
import 'package:prepnotes/core/services/file_picker_service.dart';
import 'package:prepnotes/core/theme/app_theme.dart';
import 'package:prepnotes/data/models/access.dart';
import 'package:prepnotes/data/repositories/purchases_repository.dart';
import 'package:prepnotes/data/repositories/room_repository.dart';
import 'package:prepnotes/features/auth/data/auth_repository.dart';
import 'package:prepnotes/features/auth/domain/auth_session.dart';
import 'package:prepnotes/features/purchases/data/payment_service.dart';
import 'package:prepnotes/features/resources/domain/room_links.dart';
import 'package:prepnotes/features/resources/presentation/resource_room_screen.dart';
import 'package:prepnotes/features/resources/presentation/room_item_screen.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_media.dart';
import '../../fakes/fake_purchases.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('RoomLink.parse', () {
    test('YouTube links in every common shape', () {
      for (final url in [
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'youtube.com/watch?v=dQw4w9WgXcQ&t=30',
        'https://youtu.be/dQw4w9WgXcQ',
        'https://m.youtube.com/shorts/dQw4w9WgXcQ',
        'http://www.youtube.com/embed/dQw4w9WgXcQ',
      ]) {
        final link = RoomLink.parse(url);
        expect(link?.type, RoomItemType.youtube, reason: url);
        expect(link?.id, 'dQw4w9WgXcQ', reason: url);
        expect(link!.url, startsWith('https://'));
      }
      final playlist = RoomLink.parse(
        'https://www.youtube.com/playlist?list=PL123',
      );
      expect(playlist?.type, RoomItemType.youtube);
      expect(playlist?.id, isNull);
    });

    test('Drive / Docs links and their in-app preview', () {
      final file = RoomLink.parse(
        'https://drive.google.com/file/d/1AbC_x-9/view?usp=sharing',
      )!;
      expect((file.type, file.id), (RoomItemType.drive, '1AbC_x-9'));
      expect(
        RoomLink.drivePreviewUrl(file.url),
        'https://drive.google.com/file/d/1AbC_x-9/preview',
      );
      final folder = RoomLink.parse(
        'https://drive.google.com/drive/folders/F00?usp=sharing',
      )!;
      expect(
        RoomLink.drivePreviewUrl(folder.url),
        'https://drive.google.com/embeddedfolderview?id=F00#list',
      );
      final doc = RoomLink.parse(
        'https://docs.google.com/document/d/D0C/edit',
      )!;
      expect(
        RoomLink.drivePreviewUrl(doc.url),
        'https://docs.google.com/document/d/D0C/preview',
      );
    });

    test('anything else is refused', () {
      for (final url in [
        '',
        'not a link',
        'https://example.com/notes.pdf',
        'https://drive.evil.com/file/d/x',
        'https://notyoutube.com/watch?v=dQw4w9WgXcQ',
      ]) {
        expect(RoomLink.parse(url), isNull, reason: url);
      }
    });
  });

  group('FirebaseRoomRepository', () {
    late FakeFirebaseFirestore db;
    late FirebaseRoomRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = FirebaseRoomRepository(
        db,
        storage: () => throw StateError('no storage in this test'),
      );
    });

    test('add links, search by title words, filter by type', () async {
      await repo.addLink(
        'u1',
        type: RoomItemType.youtube,
        url: 'https://youtu.be/dQw4w9WgXcQ',
        title: 'DBMS normalisation lecture',
      );
      await repo.addLink(
        'u1',
        type: RoomItemType.drive,
        url: 'https://drive.google.com/file/d/x/view',
        title: 'OS class notes',
      );
      expect((await repo.items('u1')).items, hasLength(2));
      expect(
        (await repo.items('u1', search: 'norm lec')).items.single.title,
        'DBMS normalisation lecture',
      );
      expect((await repo.items('u1', search: 'norm os')).items, isEmpty);
      expect(
        (await repo.items('u1', type: RoomItemType.drive)).items.single.title,
        'OS class notes',
      );
      // Another student's Room is separate.
      expect((await repo.items('u2')).items, isEmpty);
    });

    test('rename updates search; delete removes', () async {
      final item = await repo.addLink(
        'u1',
        type: RoomItemType.drive,
        url: 'https://drive.google.com/file/d/x/view',
        title: 'Old name',
      );
      await repo.rename('u1', item.id, 'Maths formula sheet');
      expect(
        (await repo.items('u1', search: 'formula')).items.single.id,
        item.id,
      );
      await repo.delete('u1', item.id);
      expect(await repo.item('u1', item.id), isNull);
    });

    test('uploads: wrong type or too big are refused before uploading', () {
      expect(
        repo.addFile(
          'u1',
          bytes: Uint8List(10),
          fileName: 'a.exe',
          contentType: 'application/x-msdownload',
          title: 'x',
        ),
        throwsA(
          isA<RoomException>().having(
            (e) => e.error,
            'error',
            RoomError.badType,
          ),
        ),
      );
      expect(
        repo.addFile(
          'u1',
          bytes: Uint8List(AccessRules.roomMaxFileBytes + 1),
          fileName: 'big.pdf',
          contentType: 'application/pdf',
          title: 'x',
        ),
        throwsA(
          isA<RoomException>().having(
            (e) => e.error,
            'error',
            RoomError.tooBig,
          ),
        ),
      );
    });
  });

  group('Resource Room screen', () {
    late FakeFirebaseFirestore db;
    late FakePurchasesRepository purchases;
    late FakeFilePickerService picker;

    Future<void> pump(
      WidgetTester tester, {
      double width = 1200,
      bool buyInApp = true,
      String start = RoutePaths.resources,
    }) async {
      tester.view.physicalSize = Size(width, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: start,
        routes: [
          GoRoute(
            path: RoutePaths.resources,
            builder: (_, _) => const ResourceRoomScreen(),
            routes: [
              GoRoute(
                path: 'item/:id',
                builder: (_, s) =>
                    RoomItemScreen(itemId: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/checkout/room/:plan',
            builder: (_, s) => Text('checkout:${s.pathParameters['plan']}'),
          ),
          GoRoute(
            path: RoutePaths.notes,
            builder: (_, _) => const Text('notes'),
          ),
          GoRoute(
            path: RoutePaths.purchases,
            builder: (_, _) => const Text('purchases'),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(db),
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository(const AuthSession(uid: 'u1')),
            ),
            purchasesRepositoryProvider.overrideWithValue(purchases),
            roomRepositoryProvider.overrideWithValue(
              FirebaseRoomRepository(
                db,
                storage: () => throw StateError('no storage'),
              ),
            ),
            filePickerServiceProvider.overrideWithValue(picker),
            buyInAppProvider.overrideWithValue(buyInApp),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() {
      db = FakeFirebaseFirestore();
      purchases = FakePurchasesRepository();
      picker = FakeFilePickerService();
    });

    for (final width in [400.0, 1200.0]) {
      testWidgets('closed: what it is, bundle tip and 3 plans ($width)', (
        tester,
      ) async {
        await pump(tester, width: width);
        expect(find.text(AppStrings.roomTagline), findsOneWidget);
        expect(find.text(AppStrings.roomWithBundle), findsOneWidget);
        for (final price in ['₹149', '₹399', '₹749']) {
          expect(find.text(price), findsOneWidget);
        }
        await tester.ensureVisible(find.text(AppStrings.subscribe).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppStrings.subscribe).first);
        await tester.pumpAndSettle();
        expect(find.text('checkout:m1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('closed in the phone app: Buy on website', (tester) async {
      await pump(tester, width: 400, buyInApp: false);
      expect(find.text(AppStrings.subscribe), findsNothing);
      expect(find.text(AppStrings.buyOnWebsite), findsWidgets);
    });

    group('open', () {
      setUp(() {
        purchases.access = RoomAccess(
          until: DateTime.now().add(const Duration(days: 100)),
          bytesUsed: 10 * 1024 * 1024,
        );
      });

      for (final width in [400.0, 1200.0]) {
        testWidgets('empty → add a link → listed, searchable ($width)', (
          tester,
        ) async {
          await pump(tester, width: width);
          expect(find.text(AppStrings.roomEmptyTitle), findsOneWidget);
          expect(find.text('10.0 MB of 200.0 MB used'), findsOneWidget);

          await tester.tap(find.text(AppStrings.roomAdd));
          await tester.pumpAndSettle();
          await tester.tap(find.text(AppStrings.roomAddLink));
          await tester.pumpAndSettle();

          // Not a Drive / YouTube link.
          await tester.enterText(
            find.byType(TextFormField).first,
            'https://example.com/a.pdf',
          );
          await tester.enterText(find.byType(TextFormField).last, 'Random');
          await tester.tap(find.text(AppStrings.roomSave));
          await tester.pumpAndSettle();
          expect(find.text(AppStrings.roomBadLink), findsOneWidget);

          await tester.enterText(
            find.byType(TextFormField).first,
            'https://youtu.be/dQw4w9WgXcQ',
          );
          await tester.enterText(
            find.byType(TextFormField).last,
            'DBMS lecture 1',
          );
          await tester.tap(find.text(AppStrings.roomSave));
          await tester.pumpAndSettle();
          expect(find.text('DBMS lecture 1'), findsOneWidget);
          expect(find.text(AppStrings.roomSaved), findsOneWidget);

          await tester.enterText(find.byType(TextField).first, 'physics');
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();
          expect(find.text('DBMS lecture 1'), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('type chips filter the list', (tester) async {
        final repo = FirebaseRoomRepository(
          db,
          storage: () => throw StateError(''),
        );
        await repo.addLink(
          'u1',
          type: RoomItemType.drive,
          url: 'https://drive.google.com/file/d/x/view',
          title: 'Drive notes',
        );
        await repo.addLink(
          'u1',
          type: RoomItemType.youtube,
          url: 'https://youtu.be/dQw4w9WgXcQ',
          title: 'Video',
        );
        await pump(tester);
        expect(find.text('Drive notes'), findsOneWidget);
        await tester.tap(
          find.widgetWithText(ChoiceChip, AppStrings.roomYoutube),
        );
        await tester.pumpAndSettle();
        expect(find.text('Drive notes'), findsNothing);
        expect(find.text('Video'), findsOneWidget);
      });

      testWidgets('ending soon without auto-renew → warning banner', (
        tester,
      ) async {
        purchases.access = RoomAccess(
          until: DateTime.now().add(const Duration(days: 5, hours: 2)),
        );
        await pump(tester);
        expect(find.byType(MaterialBanner), findsOneWidget);
        expect(find.textContaining('ends in 5 days'), findsOneWidget);
      });

      testWidgets('auto-renew on → no warning', (tester) async {
        purchases.access = RoomAccess(
          until: DateTime.now().add(const Duration(days: 5)),
        );
        purchases.subscription = const RoomSubscription(
          id: 'sub_1',
          userId: 'u1',
          status: 'active',
        );
        await pump(tester);
        expect(find.byType(MaterialBanner), findsNothing);
      });

      testWidgets('upload: files over 25 MB are refused up front', (
        tester,
      ) async {
        picker.nextPdf = (
          name: 'huge.pdf',
          bytes: Uint8List(AccessRules.roomMaxFileBytes + 1),
          contentType: 'application/pdf',
        );
        await pump(tester);
        await tester.tap(find.text(AppStrings.roomAdd));
        await tester.pumpAndSettle();
        await tester.tap(find.text(AppStrings.roomUpload));
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.roomTooBig), findsOneWidget);
      });

      testWidgets('a removed item shows a friendly message', (tester) async {
        await pump(tester, start: RoutePaths.roomItem('gone'));
        expect(find.text(AppStrings.roomItemNotFound), findsOneWidget);
      });
    });

    test('room access helpers', () {
      final now = DateTime(2026, 10, 7);
      final a = RoomAccess(until: DateTime(2026, 10, 17, 1), bytesUsed: 5);
      expect(a.isOpenAt(now), isTrue);
      expect(a.daysLeftAt(now), 10);
      expect(RoomAccess.closed.isOpenAt(now), isFalse);
      expect(a.bytesLeft, AccessRules.roomQuotaBytes - 5);
      expect(
        RoomPlan.fromConfig({
          'm3': {'price': 29900, 'months': 3},
        }).map((p) => p.price),
        [14900, 29900, 74900],
      );
      expect(Timestamp.now(), isNotNull);
    });
  });
}
