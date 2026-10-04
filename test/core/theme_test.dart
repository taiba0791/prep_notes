import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prepnotes/core/theme/app_colors.dart';
import 'package:prepnotes/core/theme/app_theme.dart';
import 'package:prepnotes/core/theme/app_theme_colors.dart';

void main() {
  // Tests have no internet; don't try to download fonts.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('AppTheme', () {
    test('light theme uses the brand palette', () {
      final scheme = AppTheme.light.colorScheme;
      expect(scheme.brightness, Brightness.light);
      expect(scheme.primary, AppColors.claret);
      expect(scheme.secondary, AppColors.teal);
      expect(scheme.tertiary, AppColors.marigold);
      expect(scheme.onSurface, AppColors.ink);
      expect(scheme.surface, AppColors.white);
    });

    test('dark theme uses ink surfaces and lighter brand tones', () {
      final scheme = AppTheme.dark.colorScheme;
      expect(scheme.brightness, Brightness.dark);
      expect(scheme.surface, AppColors.darkSurface);
      expect(scheme.primary, AppColors.rose);
      expect(scheme.secondary, AppColors.tealLight);
    });

    test('both themes include the AppThemeColors extension', () {
      expect(AppTheme.light.extension<AppThemeColors>(), AppThemeColors.light);
      expect(AppTheme.dark.extension<AppThemeColors>(), AppThemeColors.dark);
    });
  });
}
