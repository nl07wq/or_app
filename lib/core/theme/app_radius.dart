import 'package:flutter/material.dart';

/// ORLO Border Radius
///
/// UI Guideline v0.1

class AppRadius {
  AppRadius._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;

  static BorderRadius get small => BorderRadius.circular(sm);

  static BorderRadius get medium => BorderRadius.circular(md);

  static BorderRadius get large => BorderRadius.circular(lg);

  static BorderRadius get extraLarge => BorderRadius.circular(xl);
}
