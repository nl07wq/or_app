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
        child: Row(
          children: [
            Icon(
              Symbols.breaking_news,
              color: Theme.of(context).colorScheme.primary,
              semanticLabel: 'INFORMATION',
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('INFORMATION', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _InformationMarquee(text: notice.title)),
            if (notices.length > 1) ...[
              const SizedBox(width: AppSpacing.xs),
              _NoticeCount(count: notices.length),
            ],
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.chevron_right, size: 20),
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
  static const _travel = Duration(milliseconds: 5200);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _travel,
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
      _restart(after: _terminalPause);
    }
  }

  void _restart({required Duration after}) {
    _pauseTimer?.cancel();
    _controller.stop();
    _controller.value = 0;
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = Theme.of(context).textTheme.bodyMedium;
      if (_reducedMotion) {
        return Text(widget.text, maxLines: 1, overflow: TextOverflow.ellipsis);
      }
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      final width = painter.width;
      final travel = constraints.maxWidth + width;
      return ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          child: Text(widget.text, maxLines: 1, style: style),
          builder: (context, child) => Transform.translate(
            offset: Offset(
              constraints.maxWidth - (travel * _controller.value),
              0,
            ),
            child: child,
          ),
        ),
      );
    },
  );
}
