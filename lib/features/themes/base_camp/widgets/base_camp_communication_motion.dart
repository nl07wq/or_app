import 'dart:async';

import 'package:flutter/material.dart';

import '../base_camp_dashboard_page.dart' show BaseCampLcdGrainPainter;

enum BaseCampCommunicationKind { brief, debrief, backup }

enum BaseCampCommunicationPhase { running, success }

const baseCampCommunicationFrameDuration = Duration(milliseconds: 200);
const baseCampCommunicationMinimumDuration = Duration(milliseconds: 1000);
const baseCampCommunicationCompletionHold = Duration(milliseconds: 200);

String baseCampCommunicationTitle(BaseCampCommunicationKind kind) =>
    switch (kind) {
      BaseCampCommunicationKind.brief => 'MISSION BRIEF',
      BaseCampCommunicationKind.debrief => 'MISSION DEBRIEF',
      BaseCampCommunicationKind.backup => 'ARK BACKUP',
    };

String baseCampCommunicationStatus(
  BaseCampCommunicationKind kind,
  BaseCampCommunicationPhase phase,
) => switch ((kind, phase)) {
  (BaseCampCommunicationKind.brief, BaseCampCommunicationPhase.running) ||
  (
    BaseCampCommunicationKind.debrief,
    BaseCampCommunicationPhase.running,
  ) => 'RECEIVING...',
  (BaseCampCommunicationKind.brief, BaseCampCommunicationPhase.success) ||
  (
    BaseCampCommunicationKind.debrief,
    BaseCampCommunicationPhase.success,
  ) => 'RECEIVED',
  (BaseCampCommunicationKind.backup, BaseCampCommunicationPhase.running) =>
    'ARCHIVING...',
  (BaseCampCommunicationKind.backup, BaseCampCommunicationPhase.success) =>
    'COMPLETE',
};

/// Runs a BASE CAMP-only presentation around an existing operation Future.
///
/// The operation remains the sole source of truth. A timer can advance the
/// transfer display, but it can never turn a pending or failed operation into
/// a visual success.
abstract final class BaseCampCommunicationOverlay {
  static Future<T> run<T>(
    BuildContext context, {
    required BaseCampCommunicationKind kind,
    required Future<T> Function() task,
    bool Function(T result)? isSuccess,
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final phase = ValueNotifier(BaseCampCommunicationPhase.running);
    final entry = OverlayEntry(
      builder: (_) => ValueListenableBuilder<BaseCampCommunicationPhase>(
        valueListenable: phase,
        builder: (_, value, _) =>
            BaseCampCommunicationMotion(kind: kind, phase: value),
      ),
    );
    final minimumHold = Future<void>.delayed(
      baseCampCommunicationMinimumDuration,
    );
    overlay.insert(entry);

    T? result;
    Object? taskError;
    StackTrace? taskStackTrace;
    try {
      try {
        result = await task();
      } catch (error, stackTrace) {
        taskError = error;
        taskStackTrace = stackTrace;
      }

      await minimumHold;

      if (taskError != null) {
        Error.throwWithStackTrace(taskError, taskStackTrace!);
      }
      final value = result as T;
      if (!(isSuccess?.call(value) ?? true)) return value;

      phase.value = BaseCampCommunicationPhase.success;
      await Future<void>.delayed(baseCampCommunicationCompletionHold);
      return value;
    } finally {
      entry.remove();
      phase.dispose();
    }
  }
}

class BaseCampCommunicationMotion extends StatefulWidget {
  const BaseCampCommunicationMotion({
    super.key,
    required this.kind,
    required this.phase,
  });

  final BaseCampCommunicationKind kind;
  final BaseCampCommunicationPhase phase;

  @override
  State<BaseCampCommunicationMotion> createState() =>
      _BaseCampCommunicationMotionState();
}

class _BaseCampCommunicationMotionState
    extends State<BaseCampCommunicationMotion> {
  Timer? _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(BaseCampCommunicationMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) _syncTimer();
  }

  void _syncTimer() {
    _timer?.cancel();
    if (widget.phase == BaseCampCommunicationPhase.success) {
      _frame = 4;
      return;
    }
    _frame = 0;
    _timer = Timer.periodic(baseCampCommunicationFrameDuration, (_) {
      if (!mounted) return;
      setState(() => _frame = (_frame + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const phosphor = Color(0xffb8cf72);
    const dimPhosphor = Color(0xff4e5f37);
    const housing = Color(0xff171d13);
    const frame = Color(0xff6e7b4c);
    const lcd = Color(0xff232d1b);

    return Material(
      color: const Color(0xe6080b07),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: housing,
                  border: Border.all(color: frame, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 10),
                  ],
                ),
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: _CommunicationScrews(color: frame),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: lcd,
                          border: Border.all(color: frame),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  18,
                                  16,
                                  16,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      baseCampCommunicationTitle(widget.kind),
                                      key: const ValueKey(
                                        'base-camp-communication-title',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: phosphor,
                                        fontFamily: 'PressStart2P',
                                        fontSize: 12,
                                        height: 1.35,
                                        letterSpacing: -.4,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 92,
                                      width: double.infinity,
                                      child: CustomPaint(
                                        key: ValueKey(
                                          'base-camp-communication-frame-$_frame',
                                        ),
                                        painter: BaseCampCommunicationPainter(
                                          kind: widget.kind,
                                          frame: _frame,
                                          activeColor: phosphor,
                                          idleColor: dimPhosphor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    AnimatedDefaultTextStyle(
                                      duration:
                                          baseCampCommunicationFrameDuration,
                                      style: TextStyle(
                                        color: phosphor,
                                        fontFamily: 'PressStart2P',
                                        fontSize: 11,
                                        height: 1.25,
                                        letterSpacing: -.4,
                                        shadows:
                                            widget.phase ==
                                                BaseCampCommunicationPhase
                                                    .success
                                            ? const [
                                                Shadow(
                                                  color: phosphor,
                                                  blurRadius: 5,
                                                ),
                                              ]
                                            : const [],
                                      ),
                                      child: Text(
                                        baseCampCommunicationStatus(
                                          widget.kind,
                                          widget.phase,
                                        ),
                                        key: const ValueKey(
                                          'base-camp-communication-status',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Positioned.fill(
                                child: IgnorePointer(
                                  key: ValueKey(
                                    'base-camp-communication-lcd-grid',
                                  ),
                                  child: CustomPaint(
                                    painter: BaseCampLcdGrainPainter(
                                      negative: true,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
class BaseCampCommunicationPainter extends CustomPainter {
  const BaseCampCommunicationPainter({
    required this.kind,
    required this.frame,
    required this.activeColor,
    required this.idleColor,
  });

  final BaseCampCommunicationKind kind;
  final int frame;
  final Color activeColor;
  final Color idleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.height / 46).clamp(1.0, 2.0);
    final centerY = size.height / 2;
    final sourceCenter = Offset(size.width * .16, centerY);
    final destinationCenter = Offset(size.width * .84, centerY);
    final pixel = scale * 2;

    if (kind == BaseCampCommunicationKind.backup) {
      _paintFolder(canvas, sourceCenter, pixel);
      _paintServer(canvas, destinationCenter, pixel, frame == 4);
    } else {
      _paintDocument(canvas, sourceCenter, pixel);
      _paintComputer(canvas, destinationCenter, pixel, frame == 4);
    }

    for (var index = 0; index < 3; index++) {
      final lit = frame == 4 || index < frame;
      _paintArrow(
        canvas,
        Offset(size.width * (.36 + index * .14), centerY),
        pixel,
        lit ? activeColor : idleColor,
      );
    }
  }

  Paint _paint(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill
    ..isAntiAlias = false;

  void _pixelRect(
    Canvas canvas,
    Offset center,
    double pixel,
    Rect units,
    Color color,
  ) {
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx + units.left * pixel,
        center.dy + units.top * pixel,
        units.width * pixel,
        units.height * pixel,
      ),
      _paint(color),
    );
  }

  void _paintDocument(Canvas canvas, Offset center, double pixel) {
    _pixelRect(
      canvas,
      center,
      pixel,
      const Rect.fromLTWH(-4, -6, 7, 12),
      activeColor,
    );
    _pixelRect(
      canvas,
      center,
      pixel,
      const Rect.fromLTWH(-2, -4, 3, 1),
      idleColor,
    );
    _pixelRect(
      canvas,
      center,
      pixel,
      const Rect.fromLTWH(-2, -1, 3, 1),
      idleColor,
    );
    _pixelRect(
      canvas,
      center,
      pixel,
      const Rect.fromLTWH(-2, 2, 3, 1),
      idleColor,
    );
    _pixelRect(
      canvas,
      center,
      pixel,
      const Rect.fromLTWH(3, -4, 1, 10),
      idleColor,
    );
  }

  void _paintFolder(Canvas canvas, Offset center, double pixel) {
    _pixelRect(
      canvas,
      center,
      pixel,
      const Rect.fromLTWH(-5, -4, 4, 2),
      activeColor,
    );
    _pixelRect(
      canvas,
      center,
      pixel,
      const Rect.fromLTWH(-5, -2, 10, 7),
      activeColor,
    );
    _pixelRect(
      canvas,
      center,
      pixel,
      const Rect.fromLTWH(-3, 0, 6, 3),
      idleColor,
    );
  }

  void _paintComputer(Canvas canvas, Offset center, double pixel, bool glow) {
    final color = glow ? activeColor : idleColor;
    if (glow) {
      canvas.drawRect(
        Rect.fromCenter(center: center, width: pixel * 13, height: pixel * 13),
        _paint(activeColor.withValues(alpha: .18)),
      );
    }
    _pixelRect(
      canvas,
      center,
      pixel,
      const Rect.fromLTWH(-5, -6, 10, 9),
      color,
    );
    _pixelRect(
      canvas,
      center,
      pixel,
      const Rect.fromLTWH(-3, -4, 6, 5),
      const Color(0xff171d13),
    );
    _pixelRect(canvas, center, pixel, const Rect.fromLTWH(-1, 3, 2, 2), color);
    _pixelRect(canvas, center, pixel, const Rect.fromLTWH(-3, 5, 6, 1), color);
  }

  void _paintServer(Canvas canvas, Offset center, double pixel, bool glow) {
    final color = glow ? activeColor : idleColor;
    if (glow) {
      canvas.drawRect(
        Rect.fromCenter(center: center, width: pixel * 13, height: pixel * 15),
        _paint(activeColor.withValues(alpha: .18)),
      );
    }
    for (final y in [-6.0, -1.5, 3.0]) {
      _pixelRect(canvas, center, pixel, Rect.fromLTWH(-5, y, 10, 3.5), color);
      _pixelRect(
        canvas,
        center,
        pixel,
        Rect.fromLTWH(2, y + 1, 1, 1),
        activeColor,
      );
    }
  }

  void _paintArrow(Canvas canvas, Offset center, double pixel, Color color) {
    _pixelRect(canvas, center, pixel, const Rect.fromLTWH(-3, -1, 5, 2), color);
    _pixelRect(canvas, center, pixel, const Rect.fromLTWH(1, -3, 2, 6), color);
  }

  @override
  bool shouldRepaint(covariant BaseCampCommunicationPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.frame != frame ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.idleColor != idleColor;
}

class _CommunicationScrews extends StatelessWidget {
  const _CommunicationScrews({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      for (final alignment in const [
        Alignment.topLeft,
        Alignment.topRight,
        Alignment.bottomLeft,
        Alignment.bottomRight,
      ])
        Align(
          alignment: alignment,
          child: Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
    ],
  );
}
