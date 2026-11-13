import 'package:flutter/material.dart';

const baseCampPixelFontFamily = 'PressStart2P';
const baseCampJapaneseFontFallback = 'DotGothic16';

/// BASE CAMP-only typography. Colors and component geometry remain inherited
/// from the current application theme; only the type system changes.
abstract final class BaseCampRetroTheme {
  static bool isApplied(ThemeData theme) =>
      theme.textTheme.bodyMedium?.fontFamily == baseCampPixelFontFamily;

  static ThemeData apply(ThemeData base) {
    if (isApplied(base)) {
      return base;
    }
    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      primaryTextTheme: _textTheme(base.primaryTextTheme),
    );
  }

  static TextTheme _textTheme(TextTheme source) => TextTheme(
    displayLarge: _pixel(source.displayLarge, size: 24, height: 1.35),
    displayMedium: _pixel(source.displayMedium, size: 22, height: 1.35),
    displaySmall: _pixel(source.displaySmall, size: 20, height: 1.35),
    headlineLarge: _pixel(source.headlineLarge, size: 20, height: 1.35),
    headlineMedium: _pixel(source.headlineMedium, size: 18, height: 1.35),
    headlineSmall: _pixel(source.headlineSmall, size: 16, height: 1.4),
    titleLarge: _pixel(source.titleLarge, size: 16, height: 1.4),
    titleMedium: _pixel(source.titleMedium, size: 12, height: 1.45),
    titleSmall: _pixel(source.titleSmall, size: 10, height: 1.45),
    bodyLarge: _pixel(source.bodyLarge, size: 12, height: 1.55),
    bodyMedium: _pixel(source.bodyMedium, size: 10, height: 1.55),
    // Small copy keeps the same Latin/Japanese pixel pairing. DotGothic16 is
    // the explicit Japanese fallback rather than a smooth system font.
    bodySmall: _small(source.bodySmall, size: 10, height: 1.5),
    labelLarge: _pixel(source.labelLarge, size: 10, height: 1.45),
    labelMedium: _pixel(source.labelMedium, size: 8, height: 1.5),
    labelSmall: _small(source.labelSmall, size: 9, height: 1.45),
  );

  static TextStyle? _pixel(
    TextStyle? source, {
    required double size,
    required double height,
  }) => source?.copyWith(
    fontFamily: baseCampPixelFontFamily,
    fontFamilyFallback: const <String>[baseCampJapaneseFontFallback],
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: height,
    letterSpacing: 0,
  );

  static TextStyle? _small(
    TextStyle? source, {
    required double size,
    required double height,
  }) => source?.copyWith(
    fontFamily: baseCampPixelFontFamily,
    fontFamilyFallback: const <String>[baseCampJapaneseFontFallback],
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: height,
  );
}
