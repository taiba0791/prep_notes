import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_mode_controller.g.dart';

/// Light / dark choice, remembered on the device.
/// Default is LIGHT regardless of the device setting.
abstract final class ThemeModeStorage {
  static const _key = 'theme_mode';

  /// Reads the saved choice. Called once in `main()` before the first frame
  /// so the app never flashes the wrong theme.
  static Future<ThemeMode> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key) == ThemeMode.dark.name
          ? ThemeMode.dark
          : ThemeMode.light;
    } on Object {
      return ThemeMode.light; // storage unavailable → just use the default
    }
  }

  static Future<void> save(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } on Object {
      // Not critical: the choice simply won't be remembered.
    }
  }
}

/// The saved theme read at start-up. `main()` overrides this.
@Riverpod(keepAlive: true)
ThemeMode initialThemeMode(Ref ref) => ThemeMode.light;

@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() => ref.read(initialThemeModeProvider);

  bool get isDark => state == ThemeMode.dark;

  Future<void> toggle() async {
    state = isDark ? ThemeMode.light : ThemeMode.dark;
    await ThemeModeStorage.save(state);
  }
}
