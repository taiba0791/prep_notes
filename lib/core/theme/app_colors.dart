import 'package:material_ui/material_ui.dart';

/// The PrepNotes brand palette ("Petrol navy and coral").
///
/// This is the ONLY file that may contain raw hex colours. Widgets must read
/// colours from `Theme.of(context).colorScheme` or [AppThemeColors] instead.
abstract final class AppColors {
  // Brand
  static const petrol = Color(0xFF12394A);
  static const petrolDeep = Color(0xFF0B2530);
  static const petrolTint = Color(0xFF9FCADB);
  static const coral = Color(0xFFFF6F61);
  static const coralDeep = Color(0xFFC0392B);
  static const sand = Color(0xFFE0D0B4);
  static const sandLight = Color(0xFFF3ECDF);
  static const white = Color(0xFFFFFFFF);

  // Light-mode neutrals
  static const slate = Color(0xFF5F6B73);
  static const border = Color(0xFFE5E7EB);
  static const outline = Color(0xFFC4CCD1);
  static const surfaceDim = Color(0xFFF6F7F8);
  static const surfaceDimmer = Color(0xFFEEF1F3);

  // Dark-mode surfaces (petrol family, darkest to lightest)
  static const darkSurfaceLowest = Color(0xFF071C25);
  static const darkSurfaceLow = Color(0xFF0F2F3D);
  static const darkSurfaceHigh = Color(0xFF1A4558);
  static const darkSurfaceHighest = Color(0xFF22516A);
  static const darkText = Color(0xFFF1F5F7);
  static const darkTextMuted = Color(0xFFB5C3CA);
  static const darkOutline = Color(0xFF5D7A87);
  static const darkBorder = Color(0xFF2A4B5A);

  // Containers (soft backgrounds for chips, badges, highlighted areas)
  static const petrolContainer = Color(0xFFD6E6ED);
  static const petrolContainerDark = Color(0xFF1B4A5E);
  static const coralContainer = Color(0xFFFFE3E0);
  static const onCoralContainer = Color(0xFF5C1A14);
  static const coralContainerDark = Color(0xFF6B2A23);
  static const onCoralContainerDark = Color(0xFFFFDAD5);
  static const sandContainerDark = Color(0xFF4A3F2C);

  // Status
  static const success = Color(0xFF2E7D5B);
  static const successLight = Color(0xFF6FCF97);
  static const warning = Color(0xFFB7791F);
  static const warningLight = Color(0xFFF6C26B);
}
