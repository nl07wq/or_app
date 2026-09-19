import 'package:flutter/material.dart';

/// A standard Back affordance rendered with the STATUS CRT phosphor language.
/// System and browser navigation remain under Navigator's normal control.
class StatusCrtBackButton extends StatefulWidget {
  const StatusCrtBackButton({super.key});

  static const exitDuration = Duration(milliseconds: 180);

  @override
  State<StatusCrtBackButton> createState() => _StatusCrtBackButtonState();
}

class _StatusCrtBackButtonState extends State<StatusCrtBackButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _exitController;
  bool _popRequested = false;

  @override
  void initState() {
    super.initState();
    _exitController = AnimationController(
      vsync: this,
      duration: StatusCrtBackButton.exitDuration,
    );
  }

  void _handlePressed() {
    if (_popRequested || _exitController.isAnimating) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _popOnce();
      return;
    }
    _exitController.forward(from: 0).whenComplete(_popOnce);
  }

  void _popOnce() {
    if (!mounted || _popRequested) return;
    _popRequested = true;
    Navigator.maybePop(context);
  }

  @override
  void dispose() {
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tooltip = MaterialLocalizations.of(context).backButtonTooltip;
    return Semantics(
      button: true,
      label: tooltip,
      child: IconButton(
        key: const ValueKey('status-crt-back'),
        tooltip: tooltip,
        onPressed: _handlePressed,
        icon: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _exitController,
            builder: (context, child) {
              final progress = Curves.easeInCubic.transform(
                _exitController.value,
              );
              return ClipRect(
                key: const ValueKey('status-crt-back-exit'),
                clipper: _RightToLeftPhosphorEraseClipper(progress),
                child: const _StatusCrtBackTriangle(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RightToLeftPhosphorEraseClipper extends CustomClipper<Rect> {
  const _RightToLeftPhosphorEraseClipper(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    0,
    0,
    size.width * (1 - progress.clamp(0.0, 1.0)),
    size.height,
  );

  @override
  bool shouldReclip(covariant _RightToLeftPhosphorEraseClipper oldClipper) =>
      oldClipper.progress != progress;
}

class _StatusCrtBackTriangle extends StatelessWidget {
  const _StatusCrtBackTriangle();

  @override
  Widget build(BuildContext context) => const CustomPaint(
    key: ValueKey('status-crt-back-triangle'),
    size: Size(16, 18),
    painter: _StatusCrtBackTrianglePainter(),
  );
}

class _StatusCrtBackTrianglePainter extends CustomPainter {
  const _StatusCrtBackTrianglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final triangle = Path()
      ..moveTo(size.width * .1, size.height * .5)
      ..lineTo(size.width * .9, size.height * .08)
      ..lineTo(size.width * .9, size.height * .92)
      ..close();
    canvas.drawPath(
      triangle,
      Paint()
        ..color = const Color(0x423BCAB9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
    );
    canvas.drawPath(triangle, Paint()..color = const Color(0xFF6EBAAD));
  }

  @override
  bool shouldRepaint(covariant _StatusCrtBackTrianglePainter oldDelegate) =>
      false;
}
