import 'package:flutter/material.dart';

import 'hud_scale_painter.dart';
import 'hud_state.dart';

class HUDScale extends StatelessWidget {
  final double value;
  final double animation;
  final HUDState state;

  const HUDScale({
    super.key,
    required this.value,
    this.animation = 0,
    this.state = HUDState.idle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 1.0 + animation * 0.03),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        builder: (context, scale, child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: CustomPaint(
          painter: HUDScalePainter(
            value: value,
            animation: animation,
            state: state,
          ),
        ),
      ),
    );
  }
}
