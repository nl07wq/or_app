import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class OperationFlipTile extends StatefulWidget {
  const OperationFlipTile({
    required this.value,
    super.key,
    this.width,
    this.height = 48,
    this.textStyle,
    this.valueKey,
    this.animate = true,
  });

  final String value;
  final double? width;
  final double height;
  final TextStyle? textStyle;
  final Key? valueKey;
  final bool animate;

  @override
  State<OperationFlipTile> createState() => _OperationFlipTileState();
}

class _OperationFlipTileState extends State<OperationFlipTile> {
  Key? _effectiveValueKey;

  @override
  void initState() {
    super.initState();
    _effectiveValueKey = widget.valueKey ?? ValueKey(widget.value);
  }

  @override
  void didUpdateWidget(covariant OperationFlipTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && widget.animate) {
      _effectiveValueKey = widget.valueKey ?? ValueKey(widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: widget.width,
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => AnimatedBuilder(
                animation: animation,
                child: child,
                builder: (context, child) => Opacity(
                  opacity: animation.value,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationX((1 - animation.value) * 0.45),
                    child: child,
                  ),
                ),
              ),
              child: Text(
                widget.value,
                key: _effectiveValueKey,
                textAlign: TextAlign.center,
                style:
                    widget.textStyle ??
                    Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      height: 1,
                    ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class OperationMechanicalFlipTile extends StatefulWidget {
  const OperationMechanicalFlipTile({
    required this.value,
    super.key,
    this.width,
    this.height = 48,
    this.textStyle,
    this.animate = true,
    this.startDelay = Duration.zero,
    this.animationDuration = duration,
    this.firstPhaseRatio = defaultFirstPhaseRatio,
  }) : assert(firstPhaseRatio > 0 && firstPhaseRatio < 1);

  static const duration = Duration(milliseconds: 320);
  static const dayDuration = Duration(milliseconds: 360);
  static const stagger = Duration(milliseconds: 60);
  static const defaultFirstPhaseRatio = 0.5;
  static const dayFirstPhaseRatio = 5 / 9;

  final String value;
  final double? width;
  final double height;
  final TextStyle? textStyle;
  final bool animate;
  final Duration startDelay;
  final Duration animationDuration;
  final double firstPhaseRatio;

  @override
  State<OperationMechanicalFlipTile> createState() =>
      _OperationMechanicalFlipTileState();
}

class _OperationMechanicalFlipTileState
    extends State<OperationMechanicalFlipTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late String _settledValue = widget.value;
  String? _oldValue;
  String? _targetValue;
  Timer? _startTimer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..addStatusListener(_handleStatus);
  }

  @override
  void didUpdateWidget(covariant OperationMechanicalFlipTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationDuration != widget.animationDuration) {
      _controller.duration = widget.animationDuration;
    }
    if (oldWidget.value == widget.value) return;
    _startTimer?.cancel();
    _controller.reset();
    if (!widget.animate) {
      _settledValue = widget.value;
      _oldValue = null;
      _targetValue = null;
      _started = false;
      return;
    }
    _oldValue = _settledValue;
    _targetValue = widget.value;
    _started = false;
    if (widget.startDelay == Duration.zero) {
      _beginAnimation();
    } else {
      _startTimer = Timer(widget.startDelay, () {
        if (!mounted) return;
        setState(_beginAnimation);
      });
    }
  }

  void _beginAnimation() {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _settleTarget();
      return;
    }
    _started = true;
    _controller.forward();
  }

  void _handleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(_settleTarget);
  }

  void _settleTarget() {
    _settledValue = _targetValue ?? widget.value;
    _oldValue = null;
    _targetValue = null;
    _started = false;
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle =
        widget.textStyle ??
        Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
          height: 1,
        );
    return Container(
      width: widget.width,
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: !_started || _oldValue == null || _targetValue == null
          ? _StaticFlipValue(
              key: const ValueKey('mechanical-flip-static'),
              value: _settledValue,
              textStyle: textStyle,
            )
          : AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => _MechanicalFlipFrame(
                oldValue: _oldValue!,
                newValue: _targetValue!,
                progress: _controller.value,
                firstPhaseRatio: widget.firstPhaseRatio,
                textStyle: textStyle,
              ),
            ),
    );
  }
}

class _MechanicalFlipFrame extends StatelessWidget {
  const _MechanicalFlipFrame({
    required this.oldValue,
    required this.newValue,
    required this.progress,
    required this.firstPhaseRatio,
    required this.textStyle,
  });

  final String oldValue;
  final String newValue;
  final double progress;
  final double firstPhaseRatio;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final firstPhase = progress < firstPhaseRatio;
    final phaseProgress = firstPhase
        ? Curves.easeInCubic.transform(progress / firstPhaseRatio)
        : Curves.easeOutCubic.transform(
            (progress - firstPhaseRatio) / (1 - firstPhaseRatio),
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        _HalfFlipValue(value: newValue, upper: true, textStyle: textStyle),
        _HalfFlipValue(value: oldValue, upper: false, textStyle: textStyle),
        if (firstPhase)
          Transform(
            key: const ValueKey('mechanical-flip-old-upper'),
            alignment: Alignment.bottomCenter,
            transform: _perspectiveRotation(phaseProgress * math.pi / 2),
            child: _HalfFlipValue(
              value: oldValue,
              upper: true,
              textStyle: textStyle,
              shade: 0.12 * phaseProgress,
            ),
          )
        else
          Transform(
            key: const ValueKey('mechanical-flip-new-lower'),
            alignment: Alignment.topCenter,
            transform: _perspectiveRotation(-(1 - phaseProgress) * math.pi / 2),
            child: _HalfFlipValue(
              value: newValue,
              upper: false,
              textStyle: textStyle,
              shade: 0.12 * (1 - phaseProgress),
            ),
          ),
        const _FlipDivider(),
      ],
    );
  }

  Matrix4 _perspectiveRotation(double angle) => Matrix4.identity()
    ..setEntry(3, 2, 0.0015)
    ..rotateX(angle);
}

class _StaticFlipValue extends StatelessWidget {
  const _StaticFlipValue({
    required this.value,
    required this.textStyle,
    super.key,
  });

  final String value;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Center(
        child: Text(value, textAlign: TextAlign.center, style: textStyle),
      ),
      const _FlipDivider(),
    ],
  );
}

class _HalfFlipValue extends StatelessWidget {
  const _HalfFlipValue({
    required this.value,
    required this.upper,
    required this.textStyle,
    this.shade = 0,
  });

  final String value;
  final bool upper;
  final TextStyle? textStyle;
  final double shade;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    final alignment = upper ? Alignment.topCenter : Alignment.bottomCenter;
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: alignment,
        child: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight / 2,
          child: ClipRect(
            child: OverflowBox(
              alignment: alignment,
              minWidth: constraints.maxWidth,
              maxWidth: constraints.maxWidth,
              minHeight: constraints.maxHeight,
              maxHeight: constraints.maxHeight,
              child: ColoredBox(
                color: Color.lerp(surface, Colors.black, shade)!,
                child: Center(
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    style: textStyle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlipDivider extends StatelessWidget {
  const _FlipDivider();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.center,
    child: Container(
      height: 1,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.55),
    ),
  );
}
