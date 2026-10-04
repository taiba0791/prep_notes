import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_theme_colors.dart';

/// Central Material 3 theme for PrepNotes (light + dark).
///
/// Button roles:
/// - [FilledButton]   → main call-to-action (coral pill, e.g. "Buy now").
/// - [OutlinedButton] → secondary action (petrol outline pill).
/// - [TextButton]     → link-style action (deep coral text).
abstract final class AppTheme {
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusXLarge = 24;

  static ThemeData get light => _build(_lightScheme, AppThemeColors.light);
  static ThemeData get dark => _build(_darkScheme, AppThemeColors.dark);

  static final ColorScheme _lightScheme =
      ColorScheme.fromSeed(seedColor: AppColors.petrol).copyWith(
        primary: AppColors.petrol,
        onPrimary: AppColors.white,
        primaryContainer: AppColors.petrolContainer,
        onPrimaryContainer: AppColors.petrol,
        secondary: AppColors.coral,
        onSecondary: AppColors.petrol,
        secondaryContainer: AppColors.coralContainer,
        onSecondaryContainer: AppColors.onCoralContainer,
        tertiary: AppColors.sand,
        onTertiary: AppColors.petrol,
        tertiaryContainer: AppColors.sandLight,
        onTertiaryContainer: AppColors.petrol,
        surface: AppColors.white,
        onSurface: AppColors.petrol,
        onSurfaceVariant: AppColors.slate,
        surfaceContainerLowest: AppColors.white,
        surfaceContainerLow: AppColors.white,
        surfaceContainer: AppColors.surfaceDim,
        surfaceContainerHigh: AppColors.surfaceDim,
        surfaceContainerHighest: AppColors.surfaceDimmer,
        outline: AppColors.outline,
        outlineVariant: AppColors.border,
        inverseSurface: AppColors.petrol,
        onInverseSurface: AppColors.white,
        inversePrimary: AppColors.petrolTint,
        surfaceTint: Colors.transparent,
      );

  static final ColorScheme _darkScheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.petrol,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.petrolTint,
        onPrimary: AppColors.petrolDeep,
        primaryContainer: AppColors.petrolContainerDark,
        onPrimaryContainer: AppColors.petrolContainer,
        secondary: AppColors.coral,
        onSecondary: AppColors.petrolDeep,
        secondaryContainer: AppColors.coralContainerDark,
        onSecondaryContainer: AppColors.onCoralContainerDark,
        tertiary: AppColors.sand,
        onTertiary: AppColors.petrolDeep,
        tertiaryContainer: AppColors.sandContainerDark,
        onTertiaryContainer: AppColors.sandLight,
        surface: AppColors.petrolDeep,
        onSurface: AppColors.darkText,
        onSurfaceVariant: AppColors.darkTextMuted,
        surfaceContainerLowest: AppColors.darkSurfaceLowest,
        surfaceContainerLow: AppColors.darkSurfaceLow,
        surfaceContainer: AppColors.petrol,
        surfaceContainerHigh: AppColors.darkSurfaceHigh,
        surfaceContainerHighest: AppColors.darkSurfaceHighest,
        outline: AppColors.darkOutline,
        outlineVariant: AppColors.darkBorder,
        inverseSurface: AppColors.darkText,
        onInverseSurface: AppColors.petrolDeep,
        inversePrimary: AppColors.petrol,
        surfaceTint: Colors.transparent,
      );

  static ThemeData _build(ColorScheme scheme, AppThemeColors extra) {
    final textTheme = AppTextStyles.textTheme(scheme);
    final isLight = scheme.brightness == Brightness.light;
    // Cards: white on a white page (light) / raised petrol (dark).
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
          backgroundColor: scheme.secondary,
          foregroundColor: scheme.onSecondary,
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
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: buttonPadding,
          shape: pill,
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
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
        indicatorColor: scheme.tertiaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onTertiaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.tertiaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onTertiaryContainer),
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
