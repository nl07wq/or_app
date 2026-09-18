import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/app_clock.dart';
import '../../../core/widgets/operation_flip_tile.dart';
import '../models/operation_local_date.dart';
import '../services/operation_date_display_mode_preference.dart';
import '../state/finalize_date_transition.dart';
import 'operation_date_flip_calendar.dart';
import 'operation_date_nixie_display.dart';

/// Isolates the optional Dashboard presentation from Operation Date state.
class OperationDatePresentationSwitcher extends StatefulWidget {
  const OperationDatePresentationSwitcher({
    required this.operationDateFuture,
    required this.transitionToken,
    required this.finalizeTransition,
    super.key,
    this.preference,
  });

  final Future<OperationLocalDate> operationDateFuture;
  final int transitionToken;
  final FinalizeDateTransition? finalizeTransition;
  final OperationDateDisplayModePreference? preference;

  @override
  State<OperationDatePresentationSwitcher> createState() =>
      _OperationDatePresentationSwitcherState();
}

class _OperationDatePresentationSwitcherState
    extends State<OperationDatePresentationSwitcher>
    with SingleTickerProviderStateMixin {
  OperationDateDisplayMode _mode = OperationDateDisplayMode.flip;
  bool _userSelectedMode = false;
  bool _modeLocked = false;
  double _horizontalDragDistance = 0;
  bool _horizontalDragTriggered = false;
  int? _nixieTransitionToken;
  int _previewTransitionToken = 0;
  late final AnimationController _transitionLockController;

  static const _flipTransitionDuration = Duration(milliseconds: 500);
  static const _nixieTransitionDuration = Duration(milliseconds: 260);

  OperationDateDisplayModePreference get _preference =>
      widget.preference ?? OperationDateDisplayModePreference();

  @override
  void initState() {
    super.initState();
    _transitionLockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..addStatusListener(_handleTransitionLockStatus);
    _loadMode();
  }

  @override
  void didUpdateWidget(covariant OperationDatePresentationSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transitionToken != widget.transitionToken) {
      _modeLocked = true;
      if (widget.finalizeTransition != null) {
        _nixieTransitionToken = widget.transitionToken;
      }
      _runTransitionLock();
    }
  }

  void _handleTransitionLockStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() {
      _modeLocked = false;
      _nixieTransitionToken = null;
    });
  }

  Future<void> _loadMode() async {
    final loaded = await _preference.load();
    if (!mounted) return;
    if (!_userSelectedMode && loaded != _mode) {
      setState(() => _mode = loaded);
    }
  }

  void _applyModeToggle() {
    final next = _mode == OperationDateDisplayMode.flip
        ? OperationDateDisplayMode.nixie
        : OperationDateDisplayMode.flip;
    setState(() {
      _mode = next;
      _userSelectedMode = true;
    });
    unawaited(_preference.save(next));
  }

  /// A tap exercises the installed physical display without changing its
  /// selected presentation.  Mode selection belongs exclusively to swipes.
  void _runPreview() {
    if (_modeLocked) return;
    setState(() {
      _modeLocked = true;
      _previewTransitionToken++;
    });
    _runTransitionLock();
  }

  void _switchModeFromSwipe() {
    if (_modeLocked) return;
    _applyModeToggle();
  }

  void _runTransitionLock() {
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _transitionLockController.duration = reducedMotion
        ? Duration.zero
        : _mode == OperationDateDisplayMode.flip
        ? _flipTransitionDuration
        : _nixieTransitionDuration;
    _transitionLockController.forward(from: 0);
  }

  @override
  void dispose() {
    _transitionLockController
      ..removeStatusListener(_handleTransitionLockStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modeName = _mode.name.toUpperCase();
    return Semantics(
      label: 'OPERATION DATE DISPLAY $modeName',
      hint:
          'Tap to test the current display transition. Swipe horizontally to switch display mode.',
      button: true,
      onTap: _runPreview,
      child: GestureDetector(
        key: const ValueKey('operation-date-display-switcher'),
        behavior: HitTestBehavior.translucent,
        onTap: _runPreview,
        onHorizontalDragStart: (_) {
          _horizontalDragDistance = 0;
          _horizontalDragTriggered = false;
        },
        onHorizontalDragUpdate: (details) {
          _horizontalDragDistance += details.primaryDelta ?? 0;
          if (_horizontalDragTriggered || _horizontalDragDistance.abs() < 24) {
            return;
          }
          _horizontalDragTriggered = true;
          _switchModeFromSwipe();
        },
        child: KeyedSubtree(
          key: ValueKey('operation-date-display-$modeName'),
          child: _mode == OperationDateDisplayMode.flip
              ? _FlipDatePresentation(
                  operationDateFuture: widget.operationDateFuture,
                  transitionToken: widget.transitionToken,
                  previewTransitionToken: _previewTransitionToken,
                )
              : OperationDateNixieDisplay(
                  operationDateFuture: widget.operationDateFuture,
                  transitionToken: widget.transitionToken,
                  previewTransitionToken: _previewTransitionToken,
                  initialTransitionFrom:
                      _nixieTransitionToken == widget.transitionToken
                      ? widget.finalizeTransition?.fromDate
                      : null,
                ),
        ),
      ),
    );
  }
}

class _FlipDatePresentation extends StatelessWidget {
  const _FlipDatePresentation({
    required this.operationDateFuture,
    required this.transitionToken,
    required this.previewTransitionToken,
  });

  final Future<OperationLocalDate> operationDateFuture;
  final int transitionToken;
  final int previewTransitionToken;

  @override
  Widget build(BuildContext context) => Wrap(
    key: const ValueKey('dashboard-date-time-row'),
    spacing: 0,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: OperationDateFlipCalendar(
          operationDateFuture: operationDateFuture,
          transitionToken: transitionToken,
          previewTransitionToken: previewTransitionToken,
          tileWidth: 42,
        ),
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              height: OperationDateFlipCalendar.defaultTileHeight + 8,
              child: VerticalDivider(
                key: const ValueKey('dashboard-date-time-divider'),
                width: 1,
                thickness: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: OperationDateLiveFlipClock(
              transitionToken: transitionToken,
              previewTransitionToken: previewTransitionToken,
            ),
          ),
        ],
      ),
    ],
  );
}

class OperationDateLiveFlipClock extends StatefulWidget {
  const OperationDateLiveFlipClock({
    required this.transitionToken,
    required this.previewTransitionToken,
    super.key,
  });

  static const tileWidth = 24.0;
  static const tileHeight = OperationDateFlipCalendar.defaultTileHeight;
  static const tileGap = 6.0;
  static const pairGap = 3.0;

  final int transitionToken;
  final int previewTransitionToken;

  @override
  State<OperationDateLiveFlipClock> createState() =>
      _OperationDateLiveFlipClockState();
}

class _OperationDateLiveFlipClockState extends State<OperationDateLiveFlipClock>
    with WidgetsBindingObserver {
  late DateTime _displayedTime = AppClock.now();
  Timer? _timer;
  Animation<double>? _secondaryAnimation;
  bool _routeVisible = true;
  bool _appActive = true;
  int _consumedTransitionToken = 0;
  int _consumedPreviewTransitionToken = 0;
  int _replayToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextAnimation = ModalRoute.of(context)?.secondaryAnimation;
    if (_secondaryAnimation != nextAnimation) {
      _secondaryAnimation?.removeStatusListener(_handleRouteStatus);
      _secondaryAnimation = nextAnimation;
      _secondaryAnimation?.addStatusListener(_handleRouteStatus);
    }
    _routeVisible =
        nextAnimation == null ||
        nextAnimation.status == AnimationStatus.dismissed;
    if (_routeVisible && _appActive) {
      _displayedTime = AppClock.now();
      _scheduleNextTick();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (_appActive && _routeVisible) {
      _syncAndSchedule();
    } else {
      _timer?.cancel();
    }
  }

  void _handleRouteStatus(AnimationStatus status) {
    final visible = status == AnimationStatus.dismissed;
    if (_routeVisible == visible) return;
    _routeVisible = visible;
    if (visible && _appActive) {
      _syncAndSchedule();
    } else {
      _timer?.cancel();
    }
  }

  void _syncAndSchedule() {
    if (!mounted) return;
    final now = AppClock.now();
    if (_secondStamp(now) != _secondStamp(_displayedTime)) {
      setState(() => _displayedTime = now);
    }
    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    _timer?.cancel();
    if (!_routeVisible || !_appActive) return;
    final now = AppClock.now();
    final delay = Duration(milliseconds: 1000 - now.millisecond);
    _timer = Timer(delay, _syncAndSchedule);
  }

  int _secondStamp(DateTime value) => value.millisecondsSinceEpoch ~/ 1000;

  @override
  void dispose() {
    _timer?.cancel();
    _secondaryAnimation?.removeStatusListener(_handleRouteStatus);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transitionToken != _consumedTransitionToken) {
      _consumedTransitionToken = widget.transitionToken;
      _replayToken++;
    }
    if (widget.previewTransitionToken != _consumedPreviewTransitionToken) {
      _consumedPreviewTransitionToken = widget.previewTransitionToken;
      _replayToken++;
    }
    final values = [
      _displayedTime.hour.toString().padLeft(2, '0'),
      _displayedTime.minute.toString().padLeft(2, '0'),
      _displayedTime.second.toString().padLeft(2, '0'),
    ].expand((value) => value.split('')).toList(growable: false);
    return Semantics(
      label:
          'CURRENT TIME ${values[0]}${values[1]}:'
          '${values[2]}${values[3]}:${values[4]}${values[5]}',
      child: ExcludeSemantics(
        child: Row(
          key: const ValueKey('dashboard-live-flip-clock'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < values.length; index++) ...[
              if (index > 0)
                SizedBox(
                  width: index.isOdd
                      ? OperationDateLiveFlipClock.pairGap
                      : OperationDateLiveFlipClock.tileGap,
                  child: index == 2 || index == 4
                      ? Center(
                          child: Text(
                            ':',
                            key: ValueKey('dashboard-time-colon-${index ~/ 2}'),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                          ),
                        )
                      : null,
                ),
              OperationMechanicalFlipTile(
                key: ValueKey('dashboard-time-tile-$index'),
                value: values[index],
                width: OperationDateLiveFlipClock.tileWidth,
                height: OperationDateLiveFlipClock.tileHeight,
                replayToken: _replayToken,
                startDelay: OperationMechanicalFlipTile.stagger * index,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
