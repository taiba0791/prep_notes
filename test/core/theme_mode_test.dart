import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prepnotes/core/constants/app_strings.dart';
import 'package:prepnotes/core/theme/theme_mode_controller.dart';
import 'package:prepnotes/core/widgets/theme_mode_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('default is light, even with nothing saved', () async {
    expect(await ThemeModeStorage.load(), ThemeMode.light);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(themeModeControllerProvider), ThemeMode.light);
  });

  test('toggle switches and the choice is remembered', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(themeModeControllerProvider.notifier).toggle();
    expect(container.read(themeModeControllerProvider), ThemeMode.dark);
    expect(await ThemeModeStorage.load(), ThemeMode.dark);

    await container.read(themeModeControllerProvider.notifier).toggle();
    expect(await ThemeModeStorage.load(), ThemeMode.light);
  });

  test('starts from the saved choice', () {
    final container = ProviderContainer(
      overrides: [initialThemeModeProvider.overrideWithValue(ThemeMode.dark)],
    );
    addTearDown(container.dispose);
    expect(container.read(themeModeControllerProvider), ThemeMode.dark);
  });

  testWidgets('the button flips the app between light and dark', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: ThemeData(brightness: Brightness.light),
            darkTheme: ThemeData(brightness: Brightness.dark),
            themeMode: ref.watch(themeModeControllerProvider),
            home: const Scaffold(body: ThemeModeButton()),
          ),
        ),
      ),
    );
    Brightness brightness() =>
        Theme.of(tester.element(find.byType(ThemeModeButton))).brightness;

    expect(brightness(), Brightness.light);
    await tester.tap(find.byTooltip(AppStrings.switchToDark));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);
    expect(find.byTooltip(AppStrings.switchToLight), findsOneWidget);
  });
}
