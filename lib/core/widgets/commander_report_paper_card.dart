import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'operation_card.dart';

/// Shared light-document surface for the three Commander Center report types.
///
/// The image repeats at its native scale, so a long report keeps the same
/// paper material without scaling or exposing a tile edge.
class CommanderReportPaperCard extends StatelessWidget {
  const CommanderReportPaperCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.margin = AppSpacing.cardMargin,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius? borderRadius;

  static const _texture = AssetImage(
    'assets/images/textures/commander_report_paper.jpg',
  );

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.large;
    final scheme = Theme.of(context).colorScheme;
    const ink = Color(0xFF292822);
    final paperScheme = scheme.copyWith(
      surface: const Color(0xFFF4F0E7),
      surfaceContainerLow: const Color(0xFFECE6D9),
      surfaceContainerHighest: const Color(0xFFE4DDCF),
      onSurface: ink,
      onSurfaceVariant: ink,
    );
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: paperScheme,
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: ink,
              displayColor: ink,
            ),
        cardColor: Colors.transparent,
        cardTheme: Theme.of(context).cardTheme.copyWith(
          color: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: OperationCard(
        padding: EdgeInsets.zero,
        margin: margin,
        borderRadius: radius,
        child: Container(
          key: const ValueKey('commander-report-paper-surface'),
          decoration: BoxDecoration(
            borderRadius: radius,
            image: const DecorationImage(
              image: _texture,
              repeat: ImageRepeat.repeat,
              alignment: Alignment.topLeft,
            ),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: .72)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A readable, translucent section placed on top of a [CommanderReportPaperCard].
///
/// Keeping this material separate from the paper surface lets the document
/// texture remain present while preserving a dependable dark-ink contrast for
/// report content.
class CommanderReportDocumentSection extends StatelessWidget {
  const CommanderReportDocumentSection({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.width,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: tint ?? const Color(0xD9FFFDF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .52)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF514A3F).withValues(alpha: .06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
