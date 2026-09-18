import 'package:flutter/material.dart';

/// Static physical status indicator shared by operation-status surfaces.
///
/// A compact colored disc with the restrained local illumination used by the
/// Brief/Debrief status header. It deliberately has no white hot core or
/// multi-stage halo, and never introduces animation or a ticker.
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
          ? _IlluminatedLamp(color: color)
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
  const _IlluminatedLamp({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: .35), blurRadius: 6),
      ],
    ),
  );
}
