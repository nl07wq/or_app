import 'package:flutter/material.dart';

class HUDValue extends StatelessWidget {
  final double value;
  final String unit;

  const HUDValue({super.key, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,

      builder: (context, animatedValue, child) {
        final diff = (animatedValue - value).abs();

        final scale = 1.0 + (diff * 0.35).clamp(0.0, 0.08);

        return TweenAnimationBuilder<double>(
          tween: Tween(end: scale),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutBack,

          builder: (context, s, _) {
            return Transform.scale(
              scale: s,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: animatedValue.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 62,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -2,
                        height: 1,
                      ),
                    ),
                    TextSpan(
                      text: " $unit",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: .72),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
