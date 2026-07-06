import 'package:flutter/widgets.dart';

/// ORLO UI Spacing
///
/// Standard spacing values used throughout the application.
///
/// UI Guideline v0.2
/// Version 0.2

class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double screen = 48.0;

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: lg);

  static const EdgeInsets cardPadding = EdgeInsets.all(lg);

  static const EdgeInsets cardMargin = EdgeInsets.symmetric(vertical: 3);

  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(vertical: xl);

  static const SizedBox gapXS = SizedBox(height: xs);
  static const SizedBox gapSM = SizedBox(height: sm);
  static const SizedBox gapMD = SizedBox(height: md);
  static const SizedBox gapLG = SizedBox(height: lg);
  static const SizedBox gapXL = SizedBox(height: xl);
}
