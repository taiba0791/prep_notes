import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

/// Typography: a serif for big headings (Fraunces) and a clean sans
/// for everything else (Inter).
abstract final class AppTextStyles {
  static TextTheme textTheme(ColorScheme scheme) {
    final base = ThemeData(brightness: scheme.brightness).textTheme;

    TextStyle? serif(TextStyle? style) => style == null
        ? null
        : GoogleFonts.fraunces(textStyle: style, fontWeight: FontWeight.w400);

    final sans = GoogleFonts.interTextTheme(base);

    return sans
        .copyWith(
          displayLarge: serif(base.displayLarge),
          displayMedium: serif(base.displayMedium),
          displaySmall: serif(base.displaySmall),
          headlineLarge: serif(base.headlineLarge),
          headlineMedium: serif(base.headlineMedium),
          headlineSmall: serif(base.headlineSmall),
          titleLarge: serif(base.titleLarge),
          titleMedium: sans.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          labelLarge: sans.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        )
        // Headings and labels in the main text colour (ink / near-white)...
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        // ...paragraph text in the softer, muted colour.
        .copyWith(
          bodyLarge: sans.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          bodyMedium: sans.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          bodySmall: sans.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        );
  }
}
