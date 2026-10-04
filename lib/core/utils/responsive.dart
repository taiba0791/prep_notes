import 'package:material_ui/material_ui.dart';

/// The three layout sizes used across PrepNotes.
enum ScreenSize { mobile, tablet, desktop }

/// Width breakpoints (logical pixels).
/// mobile < 600 ≤ tablet ≤ 1024 < desktop
abstract final class Breakpoints {
  static const double tablet = 600;
  static const double desktop = 1024;

  /// Content wider than this looks stretched on big monitors; centre it.
  static const double maxContentWidth = 1200;

  static ScreenSize sizeForWidth(double width) {
    if (width < tablet) return ScreenSize.mobile;
    if (width <= desktop) return ScreenSize.tablet;
    return ScreenSize.desktop;
  }
}

/// `context.screenSize`, `context.isMobile`, ... anywhere in the widget tree.
extension ResponsiveContext on BuildContext {
  ScreenSize get screenSize =>
      Breakpoints.sizeForWidth(MediaQuery.sizeOf(this).width);

  bool get isMobile => screenSize == ScreenSize.mobile;
  bool get isTablet => screenSize == ScreenSize.tablet;
  bool get isDesktop => screenSize == ScreenSize.desktop;

  /// Picks a value per screen size. [tablet] falls back to [mobile] and
  /// [desktop] falls back to [tablet].
  ///
  /// Example: `context.responsive(mobile: 1, tablet: 2, desktop: 4)` columns.
  T responsive<T>({required T mobile, T? tablet, T? desktop}) {
    return switch (screenSize) {
      ScreenSize.mobile => mobile,
      ScreenSize.tablet => tablet ?? mobile,
      ScreenSize.desktop => desktop ?? tablet ?? mobile,
    };
  }

  /// Standard page padding: 16 / 24 / 32.
  double get pagePadding =>
      responsive<double>(mobile: 16, tablet: 24, desktop: 32);
}

/// Builds a different widget per screen size.
/// [tablet] falls back to [mobile]; [desktop] falls back to [tablet].
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    required this.mobile,
    this.tablet,
    this.desktop,
    super.key,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    final builder = context.responsive<WidgetBuilder>(
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
    return builder(context);
  }
}
