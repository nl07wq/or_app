import 'package:flutter/material.dart';

/// Static physical status indicator shared by operation-status surfaces.
///
/// A compact bright core and low-intensity halo keep the light readable
/// without introducing a ticker, animation, or neon treatment.
class StatusLamp extends StatelessWidget {
  const StatusLamp({
    super.key,
    required this.color,
    this.size = 18,
    this.illuminated = true,
    this.semanticLabel,
  });

  final Color color;
  final double size;
  final bool illuminated;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final lamp = SizedBox(
      width: size,
      height: size,
      child: illuminated
          ? _IlluminatedLamp(color: color, size: size)
          : DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color),
              ),
            ),
    );
    final label = semanticLabel;
    return label == null ? lamp : Semantics(label: label, child: lamp);
  }
}

class _IlluminatedLamp extends StatelessWidget {
  const _IlluminatedLamp({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: .18),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: .30),
          blurRadius: size * .38,
          spreadRadius: size * .04,
        ),
      ],
    ),
    child: Center(
      child: SizedBox(
        width: size * .58,
        height: size * .58,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-.25, -.3),
              radius: .9,
              colors: [
                Colors.white.withValues(alpha: .88),
                color,
                color.withValues(alpha: .82),
              ],
              stops: const [.0, .28, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: .42),
                blurRadius: size * .3,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
