import 'package:flutter/material.dart';
import '../operation_button.dart';
import 'or_loading_indicator.dart';
import 'or_loading_theme.dart';
import 'or_loading_tokens.dart';

class OrLoadingSurface extends StatelessWidget {
  final OrLoadingScope scope;
  final String? title, subtitle;
  final OrLoadingPhase state;
  final VoidCallback? onRetry;
  final Widget? child;
  const OrLoadingSurface({
    super.key,
    this.scope = OrLoadingScope.section,
    this.title,
    this.subtitle,
    this.state = OrLoadingPhase.active,
    this.onRetry,
    this.child,
  });
  @override
  Widget build(BuildContext context) {
    final tokens = OrLoadingTheme.of(context).tokens;
    final full = scope == OrLoadingScope.fullscreen;
    final heading = title ?? (full ? 'INITIALIZING' : 'LOADING');
    final detail =
        subtitle ??
        (full
            ? 'Preparing application resources'
            : 'Fetching application data');
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (full) ...[
          Text(
            'O.R.L.O.',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: tokens.subduedText,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'SYSTEM / 01',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tokens.mutedText,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 36),
        ],
        OrLoadingIndicator(
          size: full ? OrLoadingSize.full : OrLoadingSize.section,
          phase: state,
          semanticsLabel: heading,
        ),
        const SizedBox(height: 20),
        Text(
          heading,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: state == OrLoadingPhase.failed
                ? tokens.failureText
                : tokens.text,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: tokens.subduedText),
        ),
        if (state == OrLoadingPhase.failed && onRetry != null) ...[
          const SizedBox(height: 20),
          OperationButton(
            icon: Icons.refresh,
            text: 'RETRY',
            onPressed: onRetry,
          ),
        ],
        if (child != null) ...[const SizedBox(height: 16), child!],
        if (full) ...[
          const SizedBox(height: 36),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PROCESSING',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: tokens.mutedText,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                'OR-APP',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: tokens.mutedText,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ],
      ],
    );
    return full
        ? ColoredBox(
            color: tokens.background,
            child: SafeArea(
              child: Center(
                child: Padding(padding: tokens.contentPadding, child: content),
              ),
            ),
          )
        : Center(
            child: Padding(padding: tokens.contentPadding, child: content),
          );
  }
}

class OrLoadingInline extends StatelessWidget {
  final String label;
  final bool isLoading;
  final Widget? child;
  final VoidCallback? onTap;
  const OrLoadingInline({
    super.key,
    required this.label,
    required this.isLoading,
    this.child,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final tokens = OrLoadingTheme.of(context).tokens;
    return Semantics(
      button: onTap != null,
      enabled: !isLoading && onTap != null,
      label: label,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) ...[
              const OrLoadingIndicator(size: OrLoadingSize.inline),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: tokens.subduedText,
                letterSpacing: .8,
              ),
            ),
            if (child != null) ...[const SizedBox(width: 8), child!],
          ],
        ),
      ),
    );
  }
}
