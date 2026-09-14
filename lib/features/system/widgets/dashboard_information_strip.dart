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
  });

  final List<InformationNotice> notices;
  final VoidCallback onTap;

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
              child: _InformationMarquee(text: notice.title),
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
  const _InformationMarquee({required this.text});

  final String text;

  @override
  State<_InformationMarquee> createState() => _InformationMarqueeState();
}

class _InformationMarqueeState extends State<_InformationMarquee>
    with SingleTickerProviderStateMixin {
  static const _initialPause = Duration(milliseconds: 900);
  static const _terminalPause = Duration(milliseconds: 1300);
  static const _exitSafetyMargin = 12.0;
  static const _scrollSpeedPxPerSecond =
      InformationMarqueeTiming.calibratedScrollSpeedPxPerSecond;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: InformationMarqueeTiming.calibrationTravelDuration,
  )..addStatusListener(_onStatus);
  Timer? _pauseTimer;
  bool _reducedMotion = false;
  bool _tickerEnabled = true;

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
      _restart(after: _initialPause);
    }
  }

  @override
  void initState() {
    super.initState();
    _restart(after: _initialPause);
  }

  @override
  void didUpdateWidget(covariant _InformationMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _restart(after: _initialPause);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_reducedMotion) {
      _restart(after: _terminalPause, resetToStart: false);
    }
  }

  void _restart({required Duration after, bool resetToStart = true}) {
    _pauseTimer?.cancel();
    if (resetToStart) {
      _controller.stop();
      _controller.value = 0;
    }
    _pauseTimer = Timer(after, () {
      if (mounted && !_reducedMotion && _tickerEnabled) {
        _controller.forward(from: 0);
      }
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
        final style = Theme.of(context).textTheme.bodyMedium;
        if (_reducedMotion) {
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final geometry = InformationMarqueeGeometry(
          viewportWidth: constraints.maxWidth,
          textLayoutWidth: painter.width,
          exitSafetyMargin: _exitSafetyMargin,
        );
        final timing = InformationMarqueeTiming(
          geometry: geometry,
          scrollSpeedPxPerSecond: _scrollSpeedPxPerSecond,
        );
        // The same measured distance used for the exit geometry controls the
        // controller duration. Updating it here also covers ticker resizes.
        if (_controller.duration != timing.travelDuration) {
          _controller.duration = timing.travelDuration;
        }
        return AnimatedBuilder(
          animation: _controller,
          child: Text(
            widget.text,
            key: const ValueKey('dashboard-information-marquee-text'),
            maxLines: 1,
            style: style,
          ),
          builder: (context, child) => ClipRect(
            key: const ValueKey('dashboard-information-marquee-clip'),
            child: Transform.translate(
              key: const ValueKey('dashboard-information-marquee-transform'),
              offset: Offset(geometry.leftAt(_controller.value), 0),
              // Keep the text's paint box unconstrained. The ClipRect above,
              // not an inherited Text width constraint, owns all clipping.
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 0,
                maxWidth: double.infinity,
                child: child,
              ),
            ),
          ),
        );
      },
    ),
  );
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
/// The calibrated speed preserves the prior 5200ms movement for the
/// representative 390px Dashboard ticker (334px usable viewport) and its
/// existing REVIEW READY title (441.75px text layout width):
/// `(334 + 441.75 + 6) / 5.2 = 150.336538... px/s`.
class InformationMarqueeTiming {
  const InformationMarqueeTiming({
    required this.geometry,
    required this.scrollSpeedPxPerSecond,
  });

  static const calibrationTravelDuration = Duration(milliseconds: 5200);
  static const calibratedScrollSpeedPxPerSecond = 150.33653846153845;

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
