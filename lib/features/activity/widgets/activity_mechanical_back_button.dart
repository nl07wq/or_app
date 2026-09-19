import 'package:flutter/material.dart';

/// A compact directional drum for Activity's shared Back affordance.
///
/// The sequence is presentation-only: it always locks on the left direction
/// before the route is popped and has no relationship to Activity data.
class ActivityMechanicalBackButton extends StatefulWidget {
  const ActivityMechanicalBackButton({super.key});

  static const exitDuration = Duration(milliseconds: 400);

  @override
  State<ActivityMechanicalBackButton> createState() =>
      _ActivityMechanicalBackButtonState();
}

class _ActivityMechanicalBackButtonState
    extends State<ActivityMechanicalBackButton>
    with SingleTickerProviderStateMixin {
  static const _left = _Direction.left;
  static const _sequences = <List<_Direction>>[
    [_Direction.down, _Direction.up, _left],
    [_Direction.right, _left],
    [_Direction.up, _Direction.down, _left],
  ];

  late final AnimationController _controller;
  int _nextSequence = 0;
  List<_Direction> _sequence = const [_left];
  bool _popRequested = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ActivityMechanicalBackButton.exitDuration,
    );
  }

  void _handlePressed() {
    if (_popRequested || _controller.isAnimating) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _popOnce();
      return;
    }
    setState(() {
      _sequence = _sequences[_nextSequence];
      _nextSequence = (_nextSequence + 1) % _sequences.length;
    });
    _controller.forward(from: 0).whenComplete(_popOnce);
  }

  void _popOnce() {
    if (!mounted || _popRequested) return;
    _popRequested = true;
    Navigator.maybePop(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tooltip = MaterialLocalizations.of(context).backButtonTooltip;
    return Semantics(
      button: true,
      label: tooltip,
      child: IconButton(
        key: const ValueKey('activity-mechanical-back'),
        tooltip: tooltip,
        onPressed: _handlePressed,
        icon: ExcludeSemantics(
          child: _MechanicalDirectionCell(
            animation: _controller,
            sequence: _sequence,
          ),
        ),
      ),
    );
  }
}

enum _Direction { left, up, right, down }

class _MechanicalDirectionCell extends StatelessWidget {
  const _MechanicalDirectionCell({
    required this.animation,
    required this.sequence,
  });

  final Animation<double> animation;
  final List<_Direction> sequence;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('activity-mechanical-back-cell'),
    width: 30,
    height: 30,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111315),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF596066), width: .8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF171A1C), Color(0xFF282C2E), Color(0xFF151719)],
              stops: [0, .5, 1],
            ),
            border: Border(
              top: BorderSide(color: Color(0x33757B7D), width: .6),
              bottom: BorderSide(color: Color(0x99000000), width: .8),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportHeight = constraints.maxHeight * .66;
              final travel = viewportHeight;
              return AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final step = _stepFor(animation.value);
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      const Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          height: .7,
                          child: ColoredBox(color: Color(0x77464B4E)),
                        ),
                      ),
                      Center(
                        child: SizedBox(
                          key: const ValueKey(
                            'activity-mechanical-back-viewport',
                          ),
                          height: viewportHeight,
                          child: ClipRect(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (step.moving)
                                  Transform.translate(
                                    key: const ValueKey(
                                      'activity-mechanical-back-outgoing',
                                    ),
                                    offset: Offset(0, -travel * step.progress),
                                    child: Center(
                                      child: _DirectionGlyph(step.from),
                                    ),
                                  ),
                                Transform.translate(
                                  key: const ValueKey(
                                    'activity-mechanical-back-incoming',
                                  ),
                                  offset: Offset(
                                    0,
                                    travel * (1 - step.progress),
                                  ),
                                  child: Center(
                                    child: _DirectionGlyph(step.to),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    ),
  );

  _DirectionStep _stepFor(double value) {
    if (sequence.length == 1 || value >= .84) {
      return const _DirectionStep(_Direction.left, _Direction.left, 1);
    }
    final scaled = (value / .84) * sequence.length;
    final completed = scaled.floor().clamp(0, sequence.length - 1);
    final from = completed == 0 ? _Direction.left : sequence[completed - 1];
    final to = sequence[completed];
    return _DirectionStep(from, to, _detentProgress(scaled - scaled.floor()));
  }

  double _detentProgress(double value) {
    const lockFraction = .18;
    if (value <= lockFraction) return 0;
    if (value >= 1 - lockFraction) return 1;
    return Curves.easeInOutCubic.transform(
      (value - lockFraction) / (1 - lockFraction * 2),
    );
  }
}

class _DirectionStep {
  const _DirectionStep(this.from, this.to, this.progress);

  final _Direction from;
  final _Direction to;
  final double progress;

  bool get moving => from != to || progress < 1;
}

class _DirectionGlyph extends StatelessWidget {
  const _DirectionGlyph(this.direction);

  final _Direction direction;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: ValueKey('activity-mechanical-back-symbol-${direction.name}'),
    size: const Size(12, 12),
    painter: _DirectionGlyphPainter(direction),
  );
}

class _DirectionGlyphPainter extends CustomPainter {
  const _DirectionGlyphPainter(this.direction);

  final _Direction direction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rotation = switch (direction) {
      _Direction.left => -1.5707963267948966,
      _Direction.up => 0.0,
      _Direction.right => 1.5707963267948966,
      _Direction.down => 3.141592653589793,
    };
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(rotation)
      ..translate(-center.dx, -center.dy);
    final triangle = Path()
      ..moveTo(center.dx, size.height * .1)
      ..lineTo(size.width * .9, size.height * .88)
      ..lineTo(size.width * .1, size.height * .88)
      ..close();
    canvas.drawPath(
      triangle,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .7),
    );
    canvas.drawPath(triangle, Paint()..color = const Color(0xFFF0EEE4));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DirectionGlyphPainter oldDelegate) =>
      oldDelegate.direction != direction;
}
