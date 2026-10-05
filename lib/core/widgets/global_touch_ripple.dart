import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/touch_ripple_audio.dart';

const touchRippleDuration = Duration(milliseconds: 900);
const touchRippleRingDelays = [
  Duration.zero,
  Duration(milliseconds: 70),
  Duration(milliseconds: 140),
];
const touchRippleMaximumRadius = 96.0;
const touchRippleMaximumActiveEvents = 4;

@immutable
class TouchRippleEvent {
  const TouchRippleEvent({required this.position, required this.startedAt});

  final Offset position;
  final Duration startedAt;
}

@visibleForTesting
bool touchRippleExpired(TouchRippleEvent event, Duration now) =>
    now - event.startedAt >= touchRippleDuration;

@visibleForTesting
List<TouchRippleEvent> boundedTouchRippleEvents(
  List<TouchRippleEvent> events,
  TouchRippleEvent next,
) {
  final retained = List<TouchRippleEvent>.of(events);
  if (retained.length >= touchRippleMaximumActiveEvents) retained.removeAt(0);
  retained.add(next);
  return retained;
}

@visibleForTesting
double? touchRippleRingProgress(Duration age, int ringIndex) {
  final delayedAge = age - touchRippleRingDelays[ringIndex];
  if (delayedAge.isNegative || delayedAge >= touchRippleDuration) return null;
  return delayedAge.inMicroseconds / touchRippleDuration.inMicroseconds;
}

@visibleForTesting
double? touchRippleRingRadius(Duration age, int ringIndex) {
  final progress = touchRippleRingProgress(age, ringIndex);
  if (progress == null) return null;
  return touchRippleMaximumRadius * Curves.easeOutCubic.transform(progress);
}

@visibleForTesting
double? touchRippleRingOpacity(Duration age, int ringIndex) {
  final progress = touchRippleRingProgress(age, ringIndex);
  if (progress == null) return null;
  return (.44 - ringIndex * .055) * (1 - progress) * (1 - progress);
}

class GlobalTouchRipple extends StatefulWidget {
  const GlobalTouchRipple({super.key, required this.child});

  final Widget child;

  static final Map<int, TouchFeedbackSound> _claims = {};
  static void claimSuccess(int pointer) =>
      _claims[pointer] = TouchFeedbackSound.success;
  static void claimFailure(int pointer) =>
      _claims[pointer] = TouchFeedbackSound.failure;

  @override
  State<GlobalTouchRipple> createState() => _GlobalTouchRippleState();
}

class _GlobalTouchRippleState extends State<GlobalTouchRipple>
    with SingleTickerProviderStateMixin {
  final _events = <TouchRippleEvent>[];
  final _pendingAudio = <int, Timer>{};
  final _frame = ValueNotifier<_TouchRippleFrame>(_TouchRippleFrame.empty());
  final _clock = Stopwatch();
  late final Ticker _ticker;
  late final TouchRippleAudio _audio;
  bool _motionEnabled = true;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame);
    _audio = createTouchRippleAudio()..prepare();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionEnabled = !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (!_motionEnabled && _events.isNotEmpty) {
      _events.clear();
      _publishFrame();
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _pendingAudio[event.pointer]?.cancel();
    _pendingAudio[event.pointer] = Timer(const Duration(milliseconds: 32), () {
      _audio.playFromUserGesture(
        GlobalTouchRipple._claims.remove(event.pointer) ??
            TouchFeedbackSound.water,
      );
      _pendingAudio.remove(event.pointer);
    });
    if (!_motionEnabled) return;
    if (!_clock.isRunning) _clock.start();
    final nextEvents = boundedTouchRippleEvents(
      _events,
      TouchRippleEvent(
        position: event.localPosition,
        startedAt: _clock.elapsed,
      ),
    );
    _events
      ..clear()
      ..addAll(nextEvents);
    _publishFrame();
    if (!_ticker.isActive) _ticker.start();
  }

  void _onFrame(Duration _) {
    final now = _clock.elapsed;
    _events.removeWhere((event) => touchRippleExpired(event, now));
    _publishFrame();
    if (_events.isEmpty) _ticker.stop();
  }

  void _publishFrame() {
    _frame.value = _TouchRippleFrame(
      _clock.elapsed,
      List.unmodifiable(_events),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    for (final pending in _pendingAudio.values) {
      pending.cancel();
    }
    _clock.stop();
    _frame.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _onPointerDown,
    child: Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              key: const ValueKey('global-touch-ripple-overlay'),
              painter: _TouchRipplePainter(
                frame: _frame,
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    ),
  );
}

@immutable
class _TouchRippleFrame {
  const _TouchRippleFrame(this.now, this.events);
  const _TouchRippleFrame.empty() : now = Duration.zero, events = const [];

  final Duration now;
  final List<TouchRippleEvent> events;
}

class _TouchRipplePainter extends CustomPainter {
  _TouchRipplePainter({required this.frame, required this.color})
    : super(repaint: frame);

  final ValueListenable<_TouchRippleFrame> frame;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final event in frame.value.events) {
      final age = frame.value.now - event.startedAt;
      for (var index = 0; index < touchRippleRingDelays.length; index++) {
        final radius = touchRippleRingRadius(age, index);
        final opacity = touchRippleRingOpacity(age, index);
        if (radius == null || opacity == null) continue;
        canvas.drawCircle(
          event.position,
          radius,
          Paint()
            ..color = Color.lerp(
              color,
              Colors.white,
              .42,
            )!.withValues(alpha: opacity * .30)
            ..style = PaintingStyle.stroke
            ..strokeWidth = lerpDouble(
              4.0,
              1.8,
              radius / touchRippleMaximumRadius,
            )!,
        );
        canvas.drawCircle(
          event.position,
          radius,
          Paint()
            ..color = Color.lerp(
              color,
              Colors.white,
              .36,
            )!.withValues(alpha: opacity * (.48 - index * .08))
            ..style = PaintingStyle.stroke
            ..strokeWidth = lerpDouble(
              .9,
              .45,
              radius / touchRippleMaximumRadius,
            )!,
        );
      }
      if (age < const Duration(milliseconds: 180)) {
        final contactOpacity = 1 - age.inMilliseconds / 180;
        canvas.drawCircle(
          event.position,
          2 + (1 - contactOpacity) * 3,
          Paint()..color = color.withValues(alpha: contactOpacity * .20),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TouchRipplePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.frame != frame;
}
