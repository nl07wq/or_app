import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../models/information_notice.dart';

class DashboardInformationStrip extends StatelessWidget {
  const DashboardInformationStrip({
    super.key,
    required this.notices,
    required this.onTap,
    @visibleForTesting this.debugScrollSpeedPxPerSecond,
  });

  final List<InformationNotice> notices;
  final VoidCallback onTap;

  /// Test-only input used to prove that alternate speeds share the exact
  /// production renderer and endpoint geometry. Production always uses the
  /// canonical configuration below.
  final double? debugScrollSpeedPxPerSecond;

  @override
  Widget build(BuildContext context) {
    final notice = notices.first;
    return Semantics(
      button: true,
      label: 'INFORMATION: ${notice.title}',
      child: OperationCard(
        key: const ValueKey('dashboard-information-strip'),
        selectable: true,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Symbols.breaking_news,
                  color: Theme.of(context).colorScheme.primary,
                  semanticLabel: 'INFORMATION',
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'INFORMATION',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                if (notices.length > 1) ...[
                  _NoticeCount(count: notices.length),
                  const SizedBox(width: AppSpacing.xs),
                ],
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            SizedBox(
              key: const ValueKey('dashboard-information-ticker-viewport'),
              height: 26,
              width: double.infinity,
              child: _InformationMarquee(
                text: notice.title,
                scrollSpeedPxPerSecond: debugScrollSpeedPxPerSecond,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCount extends StatelessWidget {
  const _NoticeCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text('$count', style: Theme.of(context).textTheme.labelSmall),
  );
}

/// A self-contained ticker so animation frames never rebuild Dashboard. Text
/// enters from the right and travels to the left, then rests before repeating.
class _InformationMarquee extends StatefulWidget {
  const _InformationMarquee({required this.text, this.scrollSpeedPxPerSecond});

  final String text;
  final double? scrollSpeedPxPerSecond;

  @override
  State<_InformationMarquee> createState() => _InformationMarqueeState();
}

class _InformationMarqueeState extends State<_InformationMarquee>
    with SingleTickerProviderStateMixin {
  final _renderedTextKey = GlobalKey();
  double? _renderedTextWidth;
  bool _measurementScheduled = false;

  late final AnimationController _controller = AnimationController(vsync: this)
    ..addStatusListener(_onStatus);
  Timer? _pauseTimer;
  bool _reducedMotion = false;
  bool _tickerEnabled = true;
  InformationMarqueePhase _phase = InformationMarqueePhase.initialPause;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (_reducedMotion == reduced && _tickerEnabled == tickerEnabled) return;
    _reducedMotion = reduced;
    _tickerEnabled = tickerEnabled;
    if (reduced || !tickerEnabled) {
      _pauseTimer?.cancel();
      _controller.stop();
    } else {
      _enterInitialPause();
    }
  }

  @override
  void initState() {
    super.initState();
    _enterInitialPause();
  }

  @override
  void didUpdateWidget(covariant _InformationMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _renderedTextWidth = null;
      _enterInitialPause();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed ||
        _reducedMotion ||
        _phase != InformationMarqueePhase.travel) {
      return;
    }
    // Let the completed controller value (1.0) paint once while still in the
    // travel phase. The following frame switches to the explicit terminal
    // phase, whose geometry is END_X rather than a sampled controller value.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          !_reducedMotion &&
          _tickerEnabled &&
          _phase == InformationMarqueePhase.travel &&
          _controller.value == 1) {
        _enterTerminalPause();
      }
    });
  }

  void _enterInitialPause() {
    _pauseTimer?.cancel();
    _controller.stop();
    _controller.value = 0;
    if (mounted) setState(() => _phase = InformationMarqueePhase.initialPause);
    _pauseTimer = Timer(InformationMarqueeConfiguration.initialPause, () {
      if (mounted && !_reducedMotion && _tickerEnabled) {
        setState(() => _phase = InformationMarqueePhase.travel);
        _controller.forward(from: 0);
      }
    });
  }

  void _enterTerminalPause() {
    _pauseTimer?.cancel();
    setState(() => _phase = InformationMarqueePhase.terminalPause);
    _pauseTimer = Timer(InformationMarqueeConfiguration.terminalPause, () {
      if (mounted && !_reducedMotion && _tickerEnabled) _enterInitialPause();
    });
  }

  void _captureRenderedTextWidth() {
    if (_measurementScheduled) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted) return;
      final width = _renderedTextKey.currentContext?.size?.width;
      if (width == null || width <= 0) return;
      if (((_renderedTextWidth ?? 0) - width).abs() <= .01) return;
      setState(() => _renderedTextWidth = width);
    });
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final locale = Localizations.maybeLocaleOf(context);
        // Text merges an inheritable explicit style with DefaultTextStyle. Do
        // that merge here too, so the width used for timing/end geometry is
        // exactly the width used by the rendered Text on web and mobile.
        final style = DefaultTextStyle.of(
          context,
        ).style.merge(Theme.of(context).textTheme.bodyMedium);
        if (_reducedMotion) {
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
            textScaler: textScaler,
            locale: locale,
          );
        }
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textDirection: Directionality.of(context),
          textScaler: textScaler,
          locale: locale,
          maxLines: 1,
          textWidthBasis: TextWidthBasis.longestLine,
        )..layout();
        _captureRenderedTextWidth();
        final textLayoutWidth = _renderedTextWidth ?? painter.width;
        final geometry = InformationMarqueeGeometry(
          viewportWidth: constraints.maxWidth,
          textLayoutWidth: textLayoutWidth,
          exitSafetyMargin: InformationMarqueeConfiguration.exitSafetyMargin,
        );
        final timing = InformationMarqueeTiming(
          geometry: geometry,
          scrollSpeedPxPerSecond:
              widget.scrollSpeedPxPerSecond ??
              InformationMarqueeConfiguration.scrollSpeedPxPerSecond,
        );
        // The same measured distance used for the exit geometry controls the
        // controller duration. Updating it here also covers ticker resizes.
        if (_controller.duration != timing.travelDuration) {
          _controller.duration = timing.travelDuration;
        }
        return AnimatedBuilder(
          animation: _controller,
          child: KeyedSubtree(
            key: _renderedTextKey,
            child: Text(
              widget.text,
              key: const ValueKey('dashboard-information-marquee-text'),
              maxLines: 1,
              softWrap: false,
              style: style,
              textScaler: textScaler,
              locale: locale,
              textWidthBasis: TextWidthBasis.longestLine,
            ),
          ),
          builder: (context, child) {
            final progress = switch (_phase) {
              InformationMarqueePhase.initialPause => 0.0,
              InformationMarqueePhase.travel => _controller.value,
              InformationMarqueePhase.terminalPause => 1.0,
            };
            final currentX = switch (_phase) {
              InformationMarqueePhase.initialPause => geometry.startLeft,
              InformationMarqueePhase.travel => geometry.leftAt(progress),
              InformationMarqueePhase.terminalPause => geometry.endLeft,
            };
            InformationMarqueeRuntimeDiagnostics.publish(
              InformationMarqueeRuntimeSnapshot(
                phase: _phase,
                configuredSpeedPxPerSecond: timing.scrollSpeedPxPerSecond,
                viewportWidth: constraints.maxWidth,
                measuredTextWidth: painter.width,
                renderedTextWidth: _renderedTextWidth,
                travelDistance: geometry.travelDistance,
                travelDuration: timing.travelDuration,
                startLeft: geometry.startLeft,
                endLeft: geometry.endLeft,
                currentX: currentX,
                progress: progress,
              ),
            );
            return ClipRect(
              key: const ValueKey('dashboard-information-marquee-clip'),
              child: Transform.translate(
                key: const ValueKey('dashboard-information-marquee-transform'),
                offset: Offset(currentX, 0),
                // Keep the text's paint box unconstrained. The ClipRect above,
                // not an inherited Text width constraint, owns all clipping.
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: 0,
                  maxWidth: double.infinity,
                  child: child,
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

enum InformationMarqueePhase { initialPause, travel, terminalPause }

/// Production configuration shared by the Dashboard renderer and runtime
/// diagnostics. Keeping these values public makes it impossible for a debug
/// surface or test-only renderer to silently use different marquee settings.
abstract final class InformationMarqueeConfiguration {
  static const initialPause = Duration(milliseconds: 900);
  static const terminalPause = Duration(milliseconds: 1300);
  static const exitSafetyMargin = 12.0;
  static const scrollSpeedPxPerSecond = 40.0;
}

/// The ticker's one local coordinate contract. It deliberately excludes the
/// heading, card, and any global/render-tree offsets.
class InformationMarqueeGeometry {
  const InformationMarqueeGeometry({
    required this.viewportWidth,
    required this.textLayoutWidth,
    required this.exitSafetyMargin,
  });

  final double viewportWidth;
  final double textLayoutWidth;
  final double exitSafetyMargin;

  double get startLeft => viewportWidth;
  double get endLeft => -textLayoutWidth - exitSafetyMargin;
  double get travelDistance => startLeft - endLeft;

  double leftAt(double progress) =>
      startLeft + ((endLeft - startLeft) * progress.clamp(0, 1));
}

/// Timing companion for [InformationMarqueeGeometry].
///
/// The fixed visual speed applies to every notice regardless of its rendered
/// width. Geometry supplies the distance and this class derives the duration.
class InformationMarqueeTiming {
  const InformationMarqueeTiming({
    required this.geometry,
    required this.scrollSpeedPxPerSecond,
  });

  static const fixedScrollSpeedPxPerSecond =
      InformationMarqueeConfiguration.scrollSpeedPxPerSecond;

  final InformationMarqueeGeometry geometry;
  final double scrollSpeedPxPerSecond;

  Duration get travelDuration => Duration(
    microseconds:
        (geometry.travelDistance /
                scrollSpeedPxPerSecond *
                Duration.microsecondsPerSecond)
            .round(),
  );

  double get effectivePixelsPerSecond =>
      geometry.travelDistance /
      (travelDuration.inMicroseconds / Duration.microsecondsPerSecond);
}

/// A read-only snapshot from the active production ticker. It exposes timing
/// phase and geometry only; notice content and INFORMATION state remain private
/// to their existing service/detail flow.
class InformationMarqueeRuntimeSnapshot {
  const InformationMarqueeRuntimeSnapshot({
    required this.phase,
    required this.configuredSpeedPxPerSecond,
    required this.viewportWidth,
    required this.measuredTextWidth,
    required this.renderedTextWidth,
    required this.travelDistance,
    required this.travelDuration,
    required this.startLeft,
    required this.endLeft,
    required this.currentX,
    required this.progress,
  });

  final InformationMarqueePhase phase;
  final double configuredSpeedPxPerSecond;
  final double viewportWidth;
  final double measuredTextWidth;
  final double? renderedTextWidth;
  final double travelDistance;
  final Duration travelDuration;
  final double startLeft;
  final double endLeft;
  final double currentX;
  final double progress;

  @override
  bool operator ==(Object other) =>
      other is InformationMarqueeRuntimeSnapshot &&
      phase == other.phase &&
      configuredSpeedPxPerSecond == other.configuredSpeedPxPerSecond &&
      viewportWidth == other.viewportWidth &&
      measuredTextWidth == other.measuredTextWidth &&
      renderedTextWidth == other.renderedTextWidth &&
      travelDistance == other.travelDistance &&
      travelDuration == other.travelDuration &&
      startLeft == other.startLeft &&
      endLeft == other.endLeft &&
      currentX == other.currentX &&
      progress == other.progress;

  @override
  int get hashCode => Object.hashAll([
    phase,
    configuredSpeedPxPerSecond,
    viewportWidth,
    measuredTextWidth,
    renderedTextWidth,
    travelDistance,
    travelDuration,
    startLeft,
    endLeft,
    currentX,
    progress,
  ]);
}

abstract final class InformationMarqueeRuntimeDiagnostics {
  static final ValueNotifier<InformationMarqueeRuntimeSnapshot?> snapshot =
      ValueNotifier(null);

  static void publish(InformationMarqueeRuntimeSnapshot value) {
    if (snapshot.value != value) snapshot.value = value;
  }
}
