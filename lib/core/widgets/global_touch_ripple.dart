import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;
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
  const GlobalTouchRipple({
    super.key,
    required this.child,
    this.audio,
    this.onRippleEventCreated,
  });

  final Widget child;

  /// Optional injection point used by focused interaction-feedback tests.
  /// Production callers use the platform implementation.
  final TouchRippleAudio? audio;

  /// Focused test hook for proving exclusion happens before generic feedback.
  final ValueChanged<int>? onRippleEventCreated;

  static final Map<int, _TouchFeedbackOwnership> _ownership = {};
  static _GlobalTouchRippleState? _activeState;

  static void excludeGenericFeedback(int pointer) {
    final ownership = _ownership[pointer] ??= _TouchFeedbackOwnership();
    ownership.genericExcluded = true;
  }

  /// Resolves feedback from a confirmed accepted callback.
  ///
  /// Shared actionable controls use [beginSemanticFeedback] on pointer-down
  /// and [confirmSemanticFeedback] only after a completed tap. This remains
  /// available for an existing callback that already knows the action result.
  static void claimSuccess(int pointer) =>
      _claimResolved(pointer, TouchFeedbackSound.success);

  static void claimFailure(int pointer) =>
      _claimResolved(pointer, TouchFeedbackSound.failure);

  static void _claimResolved(int pointer, TouchFeedbackSound sound) {
    final ownership = _ownership[pointer] ??= _TouchFeedbackOwnership();
    ownership.genericExcluded = true;
    ownership.sound = sound;
    _activeState?._playSemanticFeedback(pointer, sound);
  }

  static void beginSemanticFeedback(
    int pointer,
    TouchFeedbackSound sound,
    Offset position,
  ) {
    final ownership = _ownership[pointer] ??= _TouchFeedbackOwnership();
    ownership
      ..genericExcluded = true
      ..sound = sound
      ..downPosition = position
      ..semanticCancelled = false;
  }

  static void updateSemanticPointer(int pointer, Offset position) {
    final ownership = _ownership[pointer];
    final downPosition = ownership?.downPosition;
    if (ownership == null || downPosition == null) return;
    if ((position - downPosition).distance > kTouchSlop) {
      ownership.semanticCancelled = true;
    }
  }

  static void cancelSemanticFeedback(int pointer) {
    final ownership = _ownership[pointer];
    if (ownership != null) ownership.semanticCancelled = true;
  }

  static void confirmSemanticFeedback(int pointer) {
    final ownership = _ownership[pointer];
    final sound = ownership?.sound;
    if (ownership == null || ownership.semanticCancelled || sound == null) {
      return;
    }
    _activeState?._playSemanticFeedback(pointer, sound);
  }

  static void _release(int pointer) => _ownership.remove(pointer);

  @override
  State<GlobalTouchRipple> createState() => _GlobalTouchRippleState();
}

class _GlobalTouchRippleState extends State<GlobalTouchRipple>
    with SingleTickerProviderStateMixin {
  final _events = <TouchRippleEvent>[];
  final _pendingAudio = <int, Timer>{};
  final _exclusionCleanup = <int, Timer>{};
  final _frame = ValueNotifier<_TouchRippleFrame>(_TouchRippleFrame.empty());
  final _clock = Stopwatch();
  late final Ticker _ticker;
  late final TouchRippleAudio _audio;
  bool _motionEnabled = true;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame);
    _audio = widget.audio ?? createTouchRippleAudio();
    _audio.prepare();
    GlobalTouchRipple._activeState = this;
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
    // Pointer dispatch reaches the root before some nested GestureDetectors.
    // Defer only this classification to the current microtask so the actual
    // hit control can mark its bounds first. Generic feedback is still never
    // created for an excluded control, and this is independent of the 32ms
    // passive-audio fallback.
    final pointer = event.pointer;
    final localPosition = event.localPosition;
    scheduleMicrotask(() => _startPointerFeedback(pointer, localPosition));
  }

  void _startPointerFeedback(int pointer, Offset localPosition) {
    final ownership = GlobalTouchRipple._ownership[pointer];
    if (ownership?.genericExcluded ?? false) {
      // A semantic region has already identified this physical control. It
      // deliberately bypasses both generic ripple creation and the delayed
      // Water Drop fallback; semantic feedback is played by its own claim.
      return;
    }
    _pendingAudio[pointer]?.cancel();
    _pendingAudio[pointer] = Timer(const Duration(milliseconds: 32), () {
      _audio.playFromUserGesture(
        GlobalTouchRipple._ownership.remove(pointer)?.sound ??
            TouchFeedbackSound.water,
      );
      _pendingAudio.remove(pointer);
    });
    if (!_motionEnabled) return;
    if (!_clock.isRunning) _clock.start();
    final nextEvents = boundedTouchRippleEvents(
      _events,
      TouchRippleEvent(position: localPosition, startedAt: _clock.elapsed),
    );
    _events
      ..clear()
      ..addAll(nextEvents);
    widget.onRippleEventCreated?.call(pointer);
    _publishFrame();
    if (!_ticker.isActive) _ticker.start();
  }

  void _playSemanticFeedback(int pointer, TouchFeedbackSound sound) {
    final ownership = GlobalTouchRipple._ownership[pointer];
    if (ownership == null || ownership.soundPlayed) return;
    ownership.soundPlayed = true;
    _audio.playFromUserGesture(sound);
  }

  void _onPointerFinished(PointerEvent event) {
    final ownership = GlobalTouchRipple._ownership[event.pointer];
    if (ownership?.genericExcluded ?? false) {
      // Some controls legitimately claim semantic success from onPressed,
      // after pointer-up. Keep ownership through that synchronous gesture
      // completion, then dispose it promptly and independently per pointer.
      _exclusionCleanup[event.pointer]?.cancel();
      _exclusionCleanup[event.pointer] = Timer(
        const Duration(milliseconds: 100),
        () {
          GlobalTouchRipple._release(event.pointer);
          _exclusionCleanup.remove(event.pointer);
        },
      );
    }
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
    for (final pending in _exclusionCleanup.values) {
      pending.cancel();
    }
    for (final pointer in _pendingAudio.keys) {
      GlobalTouchRipple._release(pointer);
    }
    if (identical(GlobalTouchRipple._activeState, this)) {
      GlobalTouchRipple._activeState = null;
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
    onPointerUp: _onPointerFinished,
    onPointerCancel: _onPointerFinished,
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

class _TouchFeedbackOwnership {
  bool genericExcluded = false;
  bool soundPlayed = false;
  bool semanticCancelled = false;
  Offset? downPosition;
  TouchFeedbackSound? sound;
}

/// Marks the exact hit-test bounds of a semantic/actionable control.
///
/// It does not consume events or alter accessibility semantics. Its only job
/// is to identify ownership before the root environmental observer can create
/// a generic ripple or queue Water Drop audio.
class SemanticFeedbackRegion extends StatelessWidget {
  const SemanticFeedbackRegion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) =>
        GlobalTouchRipple.excludeGenericFeedback(event.pointer),
    child: child,
  );
}

/// The feedback role owned by an actionable OR-APP control.
enum ActionableFeedbackResult { accepted, unavailable, silent }

/// Shared ownership boundary for every actionable control.
///
/// It keeps feature code concerned with the control's existing callback while
/// this primitive owns generic-feedback exclusion and the one semantic sound.
/// Use [unavailable] only for intentionally pointer-aware disabled controls.
/// Use [silent] only for an intentionally silent, display-only interaction.
class ActionableFeedbackRegion extends StatelessWidget {
  const ActionableFeedbackRegion({
    super.key,
    required this.child,
    this.enabled = true,
    this.result = ActionableFeedbackResult.accepted,
  });

  final Widget child;
  final bool enabled;
  final ActionableFeedbackResult result;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        GlobalTouchRipple.excludeGenericFeedback(event.pointer);
        switch (result) {
          case ActionableFeedbackResult.accepted:
            GlobalTouchRipple.beginSemanticFeedback(
              event.pointer,
              TouchFeedbackSound.success,
              event.position,
            );
          case ActionableFeedbackResult.unavailable:
            GlobalTouchRipple.beginSemanticFeedback(
              event.pointer,
              TouchFeedbackSound.failure,
              event.position,
            );
          case ActionableFeedbackResult.silent:
            break;
        }
      },
      onPointerMove: (event) => GlobalTouchRipple.updateSemanticPointer(
        event.pointer,
        event.position,
      ),
      onPointerCancel: (event) =>
          GlobalTouchRipple.cancelSemanticFeedback(event.pointer),
      onPointerUp: (event) =>
          GlobalTouchRipple.confirmSemanticFeedback(event.pointer),
      child: child,
    );
  }
}

/// Wraps a stock Material button while preserving its visual implementation.
///
/// New OR-APP IconButton, TextButton, OutlinedButton, ElevatedButton, AppBar
/// action and menu-item call sites should use this instead of adding separate
/// ripple/audio wiring. Custom tappable surfaces use [ActionableFeedbackRegion]
/// directly.
class ActionableFeedbackButton extends ActionableFeedbackRegion {
  const ActionableFeedbackButton({
    super.key,
    required super.child,
    required super.enabled,
    super.result,
  });
}

/// Applies the OR-APP actionable contract to stock Flutter controls without
/// duplicating audio or ripple policy at feature call sites.
extension ActionableFeedbackWidget on Widget {
  Widget actionableFeedback({
    bool? enabled,
    ActionableFeedbackResult result = ActionableFeedbackResult.accepted,
  }) => ActionableFeedbackButton(
    enabled: enabled ?? _hasEnabledAction(this),
    result: result,
    child: this,
  );
}

bool _hasEnabledAction(Widget widget) => switch (widget) {
  ButtonStyleButton(:final onPressed) => onPressed != null,
  IconButton(:final onPressed) => onPressed != null,
  PopupMenuButton<dynamic>(:final enabled) => enabled,
  PopupMenuItem<dynamic>(:final enabled) => enabled,
  InkWell(:final onTap, :final onDoubleTap, :final onLongPress) =>
    onTap != null || onDoubleTap != null || onLongPress != null,
  GestureDetector(:final onTap, :final onDoubleTap, :final onLongPress) =>
    onTap != null || onDoubleTap != null || onLongPress != null,
  _ => false,
};

/// Backwards-compatible name for the original accepted-action wrapper.
/// New code should use [ActionableFeedbackRegion] directly.
class SemanticFeedbackActionRegion extends ActionableFeedbackRegion {
  const SemanticFeedbackActionRegion({
    super.key,
    required super.child,
    required super.enabled,
  });
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
