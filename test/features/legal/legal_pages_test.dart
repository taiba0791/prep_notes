import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prepnotes/app.dart';
import 'package:prepnotes/core/constants/app_strings.dart';
import 'package:prepnotes/core/providers/firebase_providers.dart';
import 'package:prepnotes/core/router/app_router.dart';
import 'package:prepnotes/core/router/route_paths.dart';
import 'package:prepnotes/features/auth/data/auth_repository.dart';
import 'package:prepnotes/features/legal/domain/legal_content.dart';
import 'package:prepnotes/features/legal/presentation/legal_screens.dart';

import '../../fakes/fake_auth_repository.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// Opens [path] in the full app (guest) at the given screen size.
  Future<ProviderContainer> open(
    WidgetTester tester,
    String path, {
    Size size = const Size(1280, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const PrepNotesApp(),
      ),
    );
    container.read(appRouterProvider).go(path);
    await tester.pumpAndSettle();
    return container;
  }

  final pages = {
    RoutePaths.about: LegalContent.about,
    RoutePaths.privacy: LegalContent.privacy,
    RoutePaths.terms: LegalContent.terms,
    RoutePaths.refundPolicy: LegalContent.refund,
    RoutePaths.deliveryPolicy: LegalContent.delivery,
  };

  for (final MapEntry(key: path, value: doc) in pages.entries) {
    for (final (label, size) in const [
      ('desktop', Size(1280, 900)),
      ('phone', Size(390, 844)),
    ]) {
      testWidgets('$path shows its content on $label', (tester) async {
        await open(tester, path, size: size);
        expect(find.byType(LegalScreen), findsOneWidget);
        expect(find.text(doc.title), findsWidgets);
        expect(
          find.text(AppStrings.lastUpdated(LegalInfo.lastUpdated)),
          findsOneWidget,
        );
        expect(find.text(doc.sections.first.heading), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('every legal text mentions the contact email somewhere', (
    tester,
  ) async {
    for (final doc in [
      LegalContent.privacy,
      LegalContent.terms,
      LegalContent.refund,
      LegalContent.delivery,
    ]) {
      final all = [
        doc.intro,
        for (final s in doc.sections) ...[...s.paragraphs, ...s.bullets],
      ].join(' ');
      expect(all, contains(LegalInfo.email), reason: doc.title);
    }
  });

  for (final (label, size) in const [
    ('desktop', Size(1280, 900)),
    ('phone', Size(390, 844)),
  ]) {
    testWidgets('contact page shows the email on $label', (tester) async {
      await open(tester, RoutePaths.contact, size: size);
      expect(find.byType(ContactScreen), findsOneWidget);
      expect(find.text(LegalInfo.email), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('legal links jump between pages', (tester) async {
    final container = await open(tester, RoutePaths.privacy);
    final chip = find.widgetWithText(ActionChip, AppStrings.pageDeliveryPolicy);
    await tester.scrollUntilVisible(
      chip,
      400,
      scrollable: find
          .descendant(
            of: find.byType(LegalScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).state.uri.path,
      RoutePaths.deliveryPolicy,
    );
    expect(find.text(LegalContent.delivery.title), findsWidgets);
  });

  testWidgets('footer links to the delivery policy', (tester) async {
    await open(tester, RoutePaths.about);
    expect(find.text(AppStrings.pageDeliveryPolicy), findsWidgets);
  });
}
