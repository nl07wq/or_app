import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'dashboard_glass_card.dart';

/// Shared report surface retaining the adopted Dashboard glass treatment.
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

  @override
  Widget build(BuildContext context) => DashboardGlassCard(
    padding: padding,
    margin: margin,
    borderRadius: borderRadius,
    child: Container(
      key: const ValueKey('commander-report-paper-surface'),
      child: child,
    ),
  );
}

/// Existing report section material. It remains unchanged by the outer
/// paper-texture revert so report structure and section presentation stay put.
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
