import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_theme_colors.dart';

/// Central Material 3 theme for PrepNotes (light + dark).
///
/// Colour roles ("Claret and teal" + marigold pop):
/// - primary   = Claret   → main actions, links, selected nav item.
/// - secondary = Teal     → info bands, chips, Study Zone, progress.
/// - tertiary  = Marigold → small pops only: "Free"/"New" badges, streaks.
///
/// Button roles:
/// - [FilledButton]   → main call-to-action (claret pill, e.g. "Buy now").
/// - [OutlinedButton] → secondary action (ink outline pill).
/// - [TextButton]     → link-style action (claret text).
/// - [ElevatedButton] → alternative action (teal pill).
abstract final class AppTheme {
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 20;
  static const double radiusXLarge = 24;

  static ThemeData get light => _build(_lightScheme, AppThemeColors.light);
  static ThemeData get dark => _build(_darkScheme, AppThemeColors.dark);

  static final ColorScheme _lightScheme =
      ColorScheme.fromSeed(seedColor: AppColors.claret).copyWith(
        primary: AppColors.claret,
        onPrimary: AppColors.white,
        primaryContainer: AppColors.blush,
        onPrimaryContainer: AppColors.onBlush,
        secondary: AppColors.teal,
        onSecondary: AppColors.white,
        secondaryContainer: AppColors.mint,
        onSecondaryContainer: AppColors.onMint,
        tertiary: AppColors.marigold,
        onTertiary: AppColors.ink,
        tertiaryContainer: AppColors.marigoldLight,
        onTertiaryContainer: AppColors.onMarigoldLight,
        surface: AppColors.white,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.warmGrey,
        surfaceContainerLowest: AppColors.white,
        surfaceContainerLow: AppColors.surfaceLow,
        surfaceContainer: AppColors.surfaceMid,
        surfaceContainerHigh: AppColors.surfaceHigh,
        surfaceContainerHighest: AppColors.cream,
        outline: AppColors.outline,
        outlineVariant: AppColors.border,
        inverseSurface: AppColors.ink,
        onInverseSurface: AppColors.white,
        inversePrimary: AppColors.rose,
        surfaceTint: Colors.transparent,
      );

  static final ColorScheme _darkScheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.claret,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.rose,
        onPrimary: AppColors.onRose,
        primaryContainer: AppColors.claretContainerDark,
        onPrimaryContainer: AppColors.onClaretContainerDark,
        secondary: AppColors.tealLight,
        onSecondary: AppColors.onTealLight,
        secondaryContainer: AppColors.tealContainerDark,
        onSecondaryContainer: AppColors.onTealContainerDark,
        tertiary: AppColors.marigoldSoft,
        onTertiary: AppColors.onMarigoldSoft,
        tertiaryContainer: AppColors.marigoldContainerDark,
        onTertiaryContainer: AppColors.onMarigoldContainerDark,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkText,
        onSurfaceVariant: AppColors.darkTextMuted,
        surfaceContainerLowest: AppColors.darkSurfaceLowest,
        surfaceContainerLow: AppColors.darkSurfaceLow,
        surfaceContainer: AppColors.darkSurfaceMid,
        surfaceContainerHigh: AppColors.darkSurfaceHigh,
        surfaceContainerHighest: AppColors.darkSurfaceHighest,
        outline: AppColors.darkOutline,
        outlineVariant: AppColors.darkBorder,
        inverseSurface: AppColors.darkText,
        onInverseSurface: AppColors.ink,
        inversePrimary: AppColors.claret,
        surfaceTint: Colors.transparent,
      );

  static ThemeData _build(ColorScheme scheme, AppThemeColors extra) {
    final textTheme = AppTextStyles.textTheme(scheme);
    final isLight = scheme.brightness == Brightness.light;
    // Cards: white on a white page (light) / raised ink (dark).
    final cardColor = isLight
        ? scheme.surfaceContainerLowest
        : scheme.surfaceContainer;

    const buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    const pill = StadiumBorder();

    return ThemeData(
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [extra],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: buttonPadding,
          shape: pill,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.onSurface, width: 1.5),
          padding: buttonPadding,
          shape: pill,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: extra.link,
          shape: pill,
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.secondary,
          foregroundColor: scheme.onSecondary,
          elevation: 0,
          padding: buttonPadding,
          shape: pill,
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: pill,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelLarge,
        unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.labelLarge,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXLarge),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.secondary,
      ),
    );
  }
}

/// Shortcut: `context.appColors.link` instead of
/// `Theme.of(context).extension<AppThemeColors>()!.link`.
extension AppThemeContext on BuildContext {
  AppThemeColors get appColors => Theme.of(this).extension<AppThemeColors>()!;
}
