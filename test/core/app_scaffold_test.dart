import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prepnotes/core/constants/app_strings.dart';
import 'package:prepnotes/core/theme/app_theme.dart';
import 'package:prepnotes/core/widgets/app_scaffold.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<int?> pumpAtWidth(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    int? tapped;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: AppScaffold(
            selectedIndex: 0,
            onDestinationSelected: (i) => tapped = i,
            child: const Text('page body'),
          ),
        ),
      ),
    );
    await tester.tap(find.text(AppStrings.navResources));
    return tapped;
  }

  testWidgets('mobile shows a bottom navigation bar', (tester) async {
    final tapped = await pumpAtWidth(tester, 360);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('page body'), findsOneWidget);
    expect(tapped, 3);
  });

  testWidgets('tablet shows a compact side rail', (tester) async {
    final tapped = await pumpAtWidth(tester, 800);
    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(tapped, 3);
  });

  testWidgets('desktop shows an extended rail with the app name', (
    tester,
  ) async {
    final tapped = await pumpAtWidth(tester, 1300);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(tapped, 3);
  });

  test('there are exactly 5 main destinations', () {
    expect(appDestinations.map((d) => d.label), [
      AppStrings.navHome,
      AppStrings.navNotes,
      AppStrings.navStudyZone,
      AppStrings.navResources,
      AppStrings.navProfile,
    ]);
  });
}
