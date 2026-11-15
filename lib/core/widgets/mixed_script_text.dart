import 'package:flutter/material.dart';

/// Typography correction for lines that mix BASE CAMP's Latin pixel face
/// with its Japanese fallback. Pure Latin/Japanese strings and STANDARD's
/// single-family M PLUS typography retain Flutter's normal [Text] path.
abstract final class MixedScriptTypography {
  static const latinFamily = 'PressStart2P';
  static const japaneseFamily = 'DotGothic16';

  /// Raster measurements at 28 logical px show that this brings the Latin
  /// cap top to within one physical pixel of DotGothic16 while reducing the
  /// heavier Press Start cell density.
  static const baseCampLatinScale = .90;

  /// Proportional tightening keeps the scaled pixel cells visually cohesive
  /// without changing pure-Latin headings or instrument readouts.
  static const baseCampLatinLetterSpacingEm = -.02;

  static bool isMixed(String value) {
    var hasJapanese = false;
    var hasLatinOrDigit = false;
    for (final rune in value.runes) {
      hasJapanese = hasJapanese || _isJapanese(rune);
      hasLatinOrDigit =
          hasLatinOrDigit ||
          (rune >= 0x30 && rune <= 0x39) ||
          (rune >= 0x41 && rune <= 0x5a) ||
          (rune >= 0x61 && rune <= 0x7a);
      if (hasJapanese && hasLatinOrDigit) return true;
    }
    return false;
  }

  static bool shouldCorrect(String value, TextStyle style) =>
      isMixed(value) && style.fontFamily == latinFamily;

  static List<TextSpan> spans(String value, TextStyle style) {
    final size = style.fontSize;
    assert(size != null);
    final japaneseStyle = style.copyWith(
      fontFamily: japaneseFamily,
      fontFamilyFallback: const <String>[latinFamily],
      height: 1,
    );
    final latinStyle = style.copyWith(
      fontFamily: latinFamily,
      fontFamilyFallback: const <String>[japaneseFamily],
      fontSize: size! * baseCampLatinScale,
      height: 1,
      letterSpacing:
          (style.letterSpacing ?? 0) + size * baseCampLatinLetterSpacingEm,
    );
    final result = <TextSpan>[];
    final buffer = StringBuffer();
    bool? japanese;

    void flush() {
      if (buffer.isEmpty) return;
      result.add(
        TextSpan(
          text: buffer.toString(),
          style: japanese! ? japaneseStyle : latinStyle,
        ),
      );
      buffer.clear();
    }

    for (final rune in value.runes) {
      final nextJapanese = _isJapanese(rune);
      if (japanese != null && japanese != nextJapanese) flush();
      japanese = nextJapanese;
      buffer.writeCharCode(rune);
    }
    flush();
    return result;
  }

  static StrutStyle strut(TextStyle style) => StrutStyle(
    fontFamily: japaneseFamily,
    fontFamilyFallback: const <String>[latinFamily],
    fontSize: style.fontSize,
    fontWeight: style.fontWeight,
    fontStyle: style.fontStyle,
    height: style.height,
    leadingDistribution: TextLeadingDistribution.even,
    forceStrutHeight: true,
  );

  static bool _isJapanese(int rune) =>
      (rune >= 0x3000 && rune <= 0x30ff) ||
      (rune >= 0x31f0 && rune <= 0x31ff) ||
      (rune >= 0x3400 && rune <= 0x4dbf) ||
      (rune >= 0x4e00 && rune <= 0x9fff) ||
      (rune >= 0xf900 && rune <= 0xfaff) ||
      (rune >= 0xff66 && rune <= 0xff9d);
}

/// Drop-in [Text] presentation for user-visible strings that may mix Japanese
/// and Latin. It preserves wrapping, selection participation and semantics by
/// using only [TextSpan]s; no inline widgets or transforms are introduced.
class MixedScriptText extends StatelessWidget {
  const MixedScriptText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.semanticsIdentifier,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final String? semanticsIdentifier;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    if (!MixedScriptTypography.shouldCorrect(data, effectiveStyle)) {
      return Text(
        data,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        semanticsIdentifier: semanticsIdentifier,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    return Text.rich(
      TextSpan(children: MixedScriptTypography.spans(data, effectiveStyle)),
      style: effectiveStyle,
      strutStyle: strutStyle ?? MixedScriptTypography.strut(effectiveStyle),
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      semanticsIdentifier: semanticsIdentifier,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
