import 'package:flutter/material.dart';

/// The visual contract for OR-APP's data-bar loading family.
@immutable
class OrLoadingTokens {
  final Color background,
      text,
      subduedText,
      mutedText,
      activeBright,
      activeMedium,
      activeDim,
      successText,
      successBars,
      failureText,
      failureBars;
  final int barCount;
  final double barWidth, barGap;
  final List<double> barHeightPattern;
  final Duration motionDuration;
  final EdgeInsets contentPadding;
  const OrLoadingTokens({
    this.background = const Color(0xFF0B1119),
    this.text = const Color(0xFFE4F2F4),
    this.subduedText = const Color(0xFF91AEB8),
    this.mutedText = const Color(0xFF5B7885),
    this.activeBright = const Color(0xFF8AE7E3),
    this.activeMedium = const Color(0xFF3AADA9),
    this.activeDim = const Color(0xFF23434C),
    this.successText = const Color(0xFF81DCC5),
    this.successBars = const Color(0xFF68D8B8),
    this.failureText = const Color(0xFFE2A69A),
    this.failureBars = const Color(0xFFCF8575),
    this.barCount = 21,
    this.barWidth = 5,
    this.barGap = 4,
    this.barHeightPattern = const [30, 20, 18],
    this.motionDuration = const Duration(milliseconds: 1600),
    this.contentPadding = const EdgeInsets.all(24),
  }) : assert(barCount > 0);
  OrLoadingTokens copyWith({
    Color? background,
    Color? text,
    Color? subduedText,
    Color? mutedText,
    Color? activeBright,
    Color? activeMedium,
    Color? activeDim,
    Color? successText,
    Color? successBars,
    Color? failureText,
    Color? failureBars,
    int? barCount,
    double? barWidth,
    double? barGap,
    List<double>? barHeightPattern,
    Duration? motionDuration,
    EdgeInsets? contentPadding,
  }) => OrLoadingTokens(
    background: background ?? this.background,
    text: text ?? this.text,
    subduedText: subduedText ?? this.subduedText,
    mutedText: mutedText ?? this.mutedText,
    activeBright: activeBright ?? this.activeBright,
    activeMedium: activeMedium ?? this.activeMedium,
    activeDim: activeDim ?? this.activeDim,
    successText: successText ?? this.successText,
    successBars: successBars ?? this.successBars,
    failureText: failureText ?? this.failureText,
    failureBars: failureBars ?? this.failureBars,
    barCount: barCount ?? this.barCount,
    barWidth: barWidth ?? this.barWidth,
    barGap: barGap ?? this.barGap,
    barHeightPattern: barHeightPattern ?? this.barHeightPattern,
    motionDuration: motionDuration ?? this.motionDuration,
    contentPadding: contentPadding ?? this.contentPadding,
  );
}

enum OrLoadingSize { full, section, inline }

enum OrLoadingPhase { active, ready, failed }

enum OrLoadingScope { fullscreen, section }
