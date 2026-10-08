import 'package:flutter/material.dart';

/// Lightweight, Activity-only kinetic trajectory field.
class ActivityAmbientKineticField extends StatefulWidget {
  const ActivityAmbientKineticField({super.key, required this.enabled});

  static const fieldKey = ValueKey('activity-ambient-kinetic-field');
  final bool enabled;

  @override
  State<ActivityAmbientKineticField> createState() =>
      _ActivityAmbientKineticFieldState();
}

class _ActivityAmbientKineticFieldState
    extends State<ActivityAmbientKineticField>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.enabled && !reduced)
      _controller.repeat();
    else
      _controller.stop();
  }

  @override
  void didUpdateWidget(covariant ActivityAmbientKineticField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled)
        _controller.repeat();
      else
        _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        key: ActivityAmbientKineticField.fieldKey,
        child: CustomPaint(
          painter: _KineticPainter(
            _controller,
            Theme.of(context).colorScheme.primary,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _KineticPainter extends CustomPainter {
  _KineticPainter(this.animation, this.color) : super(repaint: animation);
  final Animation<double> animation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    for (var i = 0; i < 12; i++) {
      final x = size.width * ((i * 37 % 101) / 100);
      final y = size.height * ((i * 53 % 97) / 100);
      final r = 24.0 + (i % 4) * 19;
      paint.color = color.withValues(alpha: .05 + (i % 3) * .025);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(x, y), radius: r),
        i * .43 + t * (i.isEven ? 1 : -1) * 2,
        1.5 + (i % 3) * .28,
        false,
        paint,
      );
      final path = Path()
        ..moveTo(x - r, y + r * .3)
        ..quadraticBezierTo(x, y - r, x + r * 1.4, y + r * .5);
      canvas.drawPath(path, paint);
      final phase = (t * (12 + i % 4) + i * .17) % 1;
      final point = Offset(
        x - r + r * 2.4 * phase,
        y + r * .3 - r * 1.3 * (phase - .5) * (phase - .5),
      );
      canvas.drawCircle(
        point,
        1.5 + (i % 2),
        Paint()..color = color.withValues(alpha: .2 + (i % 4) * .08),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KineticPainter old) => old.color != color;
}
