import 'dart:ui';
import 'package:flutter/material.dart';
import 'or_loading_theme.dart';
import 'or_loading_tokens.dart';

class OrLoadingIndicator extends StatefulWidget {
  final OrLoadingSize size;
  final OrLoadingPhase phase;
  final bool? reduceMotion;
  final String? semanticsLabel;
  const OrLoadingIndicator({
    super.key,
    this.size = OrLoadingSize.full,
    this.phase = OrLoadingPhase.active,
    this.reduceMotion,
    this.semanticsLabel,
  });
  @override
  State<OrLoadingIndicator> createState() => _OrLoadingIndicatorState();
}

class _OrLoadingIndicatorState extends State<OrLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  void _sync() {
    final reduce =
        widget.reduceMotion ?? MediaQuery.disableAnimationsOf(context);
    _controller.duration = OrLoadingTheme.of(context).tokens.motionDuration;
    if (widget.phase == OrLoadingPhase.active && !reduce) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.value = widget.phase == OrLoadingPhase.ready ? 1 : 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant OrLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase ||
        oldWidget.reduceMotion != widget.reduceMotion ||
        oldWidget.size != widget.size) {
      _sync();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = OrLoadingTheme.of(context).tokens;
    final config = switch (widget.size) {
      OrLoadingSize.full => (tokens.barCount, tokens.barWidth, tokens.barGap),
      OrLoadingSize.section => (9, 4.0, 3.0),
      OrLoadingSize.inline => (5, 3.0, 2.0),
    };
    final width = config.$1 * config.$2 + (config.$1 - 1) * config.$3;
    final height = widget.size == OrLoadingSize.full
        ? 32.0
        : widget.size == OrLoadingSize.section
        ? 28.0
        : 18.0;
    return Semantics(
      label: widget.semanticsLabel ?? 'Loading',
      liveRegion: widget.phase == OrLoadingPhase.active,
      child: RepaintBoundary(
        child: SizedBox(
          width: width,
          height: height,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, _) => CustomPaint(
              key: ValueKey('or-loading-bars-${widget.size.name}'),
              painter: _OrLoadingBarsPainter(
                tokens: tokens,
                count: config.$1,
                width: config.$2,
                gap: config.$3,
                phase: widget.phase,
                progress: _controller.value,
                compact: widget.size != OrLoadingSize.full,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrLoadingBarsPainter extends CustomPainter {
  final OrLoadingTokens tokens;
  final int count;
  final double width, gap, progress;
  final OrLoadingPhase phase;
  final bool compact;
  const _OrLoadingBarsPainter({
    required this.tokens,
    required this.count,
    required this.width,
    required this.gap,
    required this.phase,
    required this.progress,
    required this.compact,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final center = (count - 1) * progress;
    for (var i = 0; i < count; i++) {
      final window = phase == OrLoadingPhase.active
          ? (1 - ((i - center).abs() / 3.5)).clamp(0.0, 1.0)
          : 0.0;
      final base =
          tokens.barHeightPattern[i % tokens.barHeightPattern.length] *
          (compact ? .78 : 1);
      final h = phase == OrLoadingPhase.ready
          ? (compact ? 22.0 : 28.0)
          : lerpDouble(base * .72, base, window)!;
      final color = switch (phase) {
        OrLoadingPhase.failed => tokens.failureBars,
        OrLoadingPhase.ready => tokens.successBars,
        OrLoadingPhase.active => Color.lerp(
          tokens.activeDim,
          Color.lerp(tokens.activeMedium, tokens.activeBright, window)!,
          .72,
        )!,
      };
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * (width + gap), size.height - h, width, h),
          const Radius.circular(1.5),
        ),
        Paint()
          ..color = color.withValues(
            alpha: phase == OrLoadingPhase.active ? .45 + .55 * window : .95,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrLoadingBarsPainter old) =>
      old.progress != progress ||
      old.phase != phase ||
      old.tokens != tokens ||
      old.count != count;
}
