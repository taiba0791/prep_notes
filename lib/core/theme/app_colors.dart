import 'package:material_ui/material_ui.dart';

/// The PrepNotes brand palette ("Claret and teal" + a marigold pop).
///
/// This is the ONLY file that may contain raw hex colours. Widgets must read
/// colours from `Theme.of(context).colorScheme` or [AppThemeColors] instead.
abstract final class AppColors {
  // Brand
  static const claret = Color(0xFF8F1D3F);
  static const teal = Color(0xFF0E6E73);
  static const ink = Color(0xFF1E1B1A);
  static const white = Color(0xFFFFFFFF);
  static const cream = Color(0xFFEFE3D3);

  // Pop accent: used sparingly (badges, "Free", streaks).
  static const marigold = Color(0xFFF2A93B);

  // Soft tints (chip / icon / highlight backgrounds)
  static const blush = Color(0xFFF8E1E8);
  static const onBlush = Color(0xFF5A0F27);
  static const mint = Color(0xFFD5ECEC);
  static const onMint = Color(0xFF063E41);
  static const marigoldLight = Color(0xFFFCEBCB);
  static const onMarigoldLight = Color(0xFF5C3A00);

  // Light-mode neutrals (warm greys to match the cream)
  static const warmGrey = Color(0xFF6B6461);
  static const outline = Color(0xFFCFC8C4);
  static const border = Color(0xFFE8E2DE);
  static const surfaceLow = Color(0xFFFBF8F3);
  static const surfaceMid = Color(0xFFF6F0E7);
  static const surfaceHigh = Color(0xFFF1E8DB);

  // Dark mode: ink surfaces, darkest to lightest
  static const darkSurface = Color(0xFF171413);
  static const darkSurfaceLowest = Color(0xFF110F0E);
  static const darkSurfaceLow = Color(0xFF1E1B1A);
  static const darkSurfaceMid = Color(0xFF262221);
  static const darkSurfaceHigh = Color(0xFF302B29);
  static const darkSurfaceHighest = Color(0xFF3A3432);
  static const darkText = Color(0xFFF4EFEC);
  static const darkTextMuted = Color(0xFFCBC2BE);
  static const darkOutline = Color(0xFF8C827E);
  static const darkBorder = Color(0xFF3F3936);
  static const darkCream = Color(0xFF2E2724);

  // Dark mode: lighter brand tones so they stay readable on ink
  static const rose = Color(0xFFF28CAB);
  static const onRose = Color(0xFF4A0A1F);
  static const claretContainerDark = Color(0xFF6E1631);
  static const onClaretContainerDark = Color(0xFFFFD9E3);
  static const tealLight = Color(0xFF6FC9C9);
  static const onTealLight = Color(0xFF003638);
  static const tealContainerDark = Color(0xFF0B5458);
  static const onTealContainerDark = Color(0xFFC9F0EF);
  static const marigoldSoft = Color(0xFFF6C26B);
  static const onMarigoldSoft = Color(0xFF3D2600);
  static const marigoldContainerDark = Color(0xFF5C4100);
  static const onMarigoldContainerDark = Color(0xFFFFE2B0);

  // Status
  static const success = Color(0xFF2F855A);
  static const successLight = Color(0xFF7BD3A0);
  static const warning = Color(0xFFC2410C);
  static const warningLight = Color(0xFFFDBA74);
}
