import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// Extra brand colours that Material's [ColorScheme] has no slot for.
///
/// Read in widgets with `Theme.of(context).extension<AppThemeColors>()!`
/// or the shorter `context.appColors` (see `app_theme.dart`).
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.link,
    required this.highlight,
    required this.cream,
    required this.success,
    required this.warning,
  });

  /// Text links such as "View program →".
  final Color link;

  /// The italic accent word in headings ("From Campus to a Top-Tech *Offer*").
  final Color highlight;

  /// Warm background for illustrations, hero shapes and icon circles.
  final Color cream;

  /// Positive states, e.g. "Purchased", "Resolved".
  final Color success;

  /// Attention states, e.g. "Pending", low time left on a timer.
  final Color warning;

  static const light = AppThemeColors(
    link: AppColors.claret,
    highlight: AppColors.claret,
    cream: AppColors.cream,
    success: AppColors.success,
    warning: AppColors.warning,
  );

  static const dark = AppThemeColors(
    link: AppColors.roseLight,
    highlight: AppColors.roseLight,
    cream: AppColors.darkCream,
    success: AppColors.successLight,
    warning: AppColors.warningLight,
  );

  @override
  AppThemeColors copyWith({
    Color? link,
    Color? highlight,
    Color? cream,
    Color? success,
    Color? warning,
  }) {
    return AppThemeColors(
      link: link ?? this.link,
      highlight: highlight ?? this.highlight,
      cream: cream ?? this.cream,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppThemeColors lerp(AppThemeColors? other, double t) {
    if (other == null) return this;
    return AppThemeColors(
      link: Color.lerp(link, other.link, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      cream: Color.lerp(cream, other.cream, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}
