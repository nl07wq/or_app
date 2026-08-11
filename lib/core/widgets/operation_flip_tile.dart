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
