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
    required this.success,
    required this.warning,
  });

  /// Text links such as "View program →".
  final Color link;

  /// The coral italic word in headings ("From Campus to a Top-Tech *Offer*").
  final Color highlight;

  /// Positive states, e.g. "Purchased", "Resolved".
  final Color success;

  /// Attention states, e.g. "Pending", low time left on a timer.
  final Color warning;

  static const light = AppThemeColors(
    link: AppColors.coralDeep,
    highlight: AppColors.coralDeep,
    success: AppColors.success,
    warning: AppColors.warning,
  );

  static const dark = AppThemeColors(
    link: AppColors.coral,
    highlight: AppColors.coral,
    success: AppColors.successLight,
    warning: AppColors.warningLight,
  );

  @override
  AppThemeColors copyWith({
    Color? link,
    Color? highlight,
    Color? success,
    Color? warning,
  }) {
    return AppThemeColors(
      link: link ?? this.link,
      highlight: highlight ?? this.highlight,
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
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}
