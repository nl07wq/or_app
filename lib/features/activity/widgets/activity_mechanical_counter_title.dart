import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/widgets/dashboard_glass_card.dart';

enum ActivityMechanicalCounterMode { normal, entry }

/// A compact mechanical totalizer used as the shared Activity AppBar title.
///
/// The counter only animates presentation glyphs. It has no relationship to
/// Activity state, records, or accumulated values.
class ActivityMechanicalCounterTitle extends StatefulWidget {
  const ActivityMechanicalCounterTitle({
    super.key,
    this.title = word,
    this.mode = ActivityMechanicalCounterMode.normal,
    this.entryEventMinDelay = const Duration(seconds: 8),
    this.entryEventMaxDelay = const Duration(seconds: 20),
    this.nextInt,
  });

  static const word = 'ACTIVITY';
  static const recordTitle = 'ACTIVITY RECORD';
  static const _recordWindow = ' RECORD ';
  static const width = 136.0;
  static const height = 34.0;
  static const cellCount = word.length;
  static const initialIndexDuration = Duration(milliseconds: 1120);
  static const periodicIndexDuration = Duration(milliseconds: 480);

  /// The complete accessible title.  The physical register remains eight
  /// cells wide; RECORD mode alternates its two mechanical registrations.
  final String title;
  final ActivityMechanicalCounterMode mode;
  final Duration entryEventMinDelay;
  final Duration entryEventMaxDelay;

  /// Test injection only; production uses a local random source for the
  /// bounded ENTRY-only mechanical registration events.
  final int Function(int max)? nextInt;

  @override
  State<ActivityMechanicalCounterTitle> createState() =>
      _ActivityMechanicalCounterTitleState();
}

class _ActivityMechanicalCounterTitleState
    extends State<ActivityMechanicalCounterTitle>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  final Random _random = Random();
  Timer? _entryEventTimer;
  Timer? _recordTransitionTimer;
  List<_CounterMotionPlan?> _plans = List<_CounterMotionPlan?>.filled(
    ActivityMechanicalCounterTitle.cellCount,
    null,
  );
  Set<int> _lastPeriodicCells = <int>{};
  bool _motionEnabled = true;
  bool _appActive = true;
  bool _initializing = false;
  bool _periodicIndexing = false;
  bool _recordIndexing = false;
  bool _initialRequested = false;
  bool _showingRecordWindow = false;

  bool get _isEntry => widget.mode == ActivityMechanicalCounterMode.entry;
  bool get _isRecordMode =>
      widget.title == ActivityMechanicalCounterTitle.recordTitle;
  String get _displayWord => _isRecordMode && _showingRecordWindow
      ? ActivityMechanicalCounterTitle._recordWindow
      : ActivityMechanicalCounterTitle.word;
  bool get _canAnimate =>
      _motionEnabled && _appActive && TickerMode.valuesOf(context).enabled;

  int _nextInt(int max) => widget.nextInt?.call(max) ?? _random.nextInt(max);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(vsync: this)
      ..addStatusListener(_handleMotionStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducedMotion) {
      _motionEnabled = false;
      _entryEventTimer?.cancel();
      _recordTransitionTimer?.cancel();
      _controller.value = 1;
      _plans = List<_CounterMotionPlan?>.filled(
        ActivityMechanicalCounterTitle.cellCount,
        null,
      );
      _initializing = false;
      _periodicIndexing = false;
      _recordIndexing = false;
      return;
    }
    _motionEnabled = true;
    if (!_canAnimate) {
      _entryEventTimer?.cancel();
      _recordTransitionTimer?.cancel();
      _controller.stop();
      return;
    }
    if (!_initialRequested) {
      _initialRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _canAnimate) _beginInitialIndex();
      });
    } else if (!_initializing && !_periodicIndexing && !_recordIndexing) {
      _scheduleNextMotion();
    }
  }

  @override
  void didUpdateWidget(covariant ActivityMechanicalCounterTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode == widget.mode && oldWidget.title == widget.title) {
      return;
    }
    _entryEventTimer?.cancel();
    _recordTransitionTimer?.cancel();
    if (oldWidget.title != widget.title) {
      _showingRecordWindow = false;
    }
    if (!_initializing && !_periodicIndexing && !_recordIndexing) {
      _scheduleNextMotion();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_appActive == active) return;
    _appActive = active;
    if (!active) {
      _entryEventTimer?.cancel();
      _recordTransitionTimer?.cancel();
      _controller.stop();
      return;
    }
    if (!_canAnimate) return;
    if (_controller.value < 1 &&
        (_initializing || _periodicIndexing || _recordIndexing)) {
      _controller.forward();
    } else if (!_initializing && !_periodicIndexing && !_recordIndexing) {
      _scheduleNextMotion();
    }
  }

  void _beginInitialIndex() {
    if (!_canAnimate) return;
    _entryEventTimer?.cancel();
    _recordTransitionTimer?.cancel();
    setState(() {
      _initializing = true;
      _periodicIndexing = false;
      _recordIndexing = false;
      _plans = [
        for (
          var index = 0;
          index < ActivityMechanicalCounterTitle.cellCount;
          index++
        )
          _CounterMotionPlan.initial(detents: index.isEven ? 2 : 3),
      ];
      _controller.duration =
          ActivityMechanicalCounterTitle.initialIndexDuration;
    });
    _controller.forward(from: 0);
  }

  void _handleMotionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    if (_initializing) {
      setState(() {
        _initializing = false;
        _plans = List<_CounterMotionPlan?>.filled(
          ActivityMechanicalCounterTitle.cellCount,
          null,
        );
      });
      _scheduleNextMotion();
      return;
    }
    if (_periodicIndexing) {
      setState(() {
        _periodicIndexing = false;
        _plans = List<_CounterMotionPlan?>.filled(
          ActivityMechanicalCounterTitle.cellCount,
          null,
        );
      });
      _scheduleNextMotion();
      return;
    }
    if (_recordIndexing) {
      setState(() {
        _recordIndexing = false;
        _showingRecordWindow = !_showingRecordWindow;
        _plans = List<_CounterMotionPlan?>.filled(
          ActivityMechanicalCounterTitle.cellCount,
          null,
        );
      });
      _scheduleNextMotion();
    }
  }

  void _scheduleNextMotion() {
    if (_isRecordMode) {
      _scheduleRecordTransition();
    } else {
      _scheduleEntryEvent();
    }
  }

  void _scheduleEntryEvent() {
    if (!_isEntry ||
        _isRecordMode ||
        !_canAnimate ||
        _initializing ||
        _periodicIndexing ||
        _recordIndexing) {
      return;
    }
    _entryEventTimer?.cancel();
    final minimum = widget.entryEventMinDelay.inMilliseconds;
    final maximum = widget.entryEventMaxDelay.inMilliseconds;
    final delay = minimum + _nextInt(maximum - minimum + 1);
    _entryEventTimer = Timer(Duration(milliseconds: delay), _beginEntryEvent);
  }

  void _beginEntryEvent() {
    if (!mounted || !_isEntry || !_canAnimate) return;
    final count = 1 + _nextInt(3);
    final cells = <int>{};
    while (cells.length < count) {
      cells.add(_nextInt(ActivityMechanicalCounterTitle.cellCount));
    }
    if (cells.length == _lastPeriodicCells.length &&
        cells.containsAll(_lastPeriodicCells)) {
      cells
        ..remove(cells.first)
        ..add(
          (_lastPeriodicCells.first + 1) %
              ActivityMechanicalCounterTitle.cellCount,
        );
    }
    _lastPeriodicCells = cells;
    setState(() {
      _periodicIndexing = true;
      _plans = [
        for (
          var index = 0;
          index < ActivityMechanicalCounterTitle.cellCount;
          index++
        )
          cells.contains(index)
              ? _CounterMotionPlan.periodic(detents: 1 + _nextInt(2))
              : null,
      ];
      _controller.duration =
          ActivityMechanicalCounterTitle.periodicIndexDuration;
    });
    _controller.forward(from: 0);
  }

  void _scheduleRecordTransition() {
    if (!_isRecordMode ||
        !_canAnimate ||
        _initializing ||
        _periodicIndexing ||
        _recordIndexing) {
      return;
    }
    _recordTransitionTimer?.cancel();
    _recordTransitionTimer = Timer(
      const Duration(milliseconds: 1800),
      _beginRecordTransition,
    );
  }

  void _beginRecordTransition() {
    if (!mounted || !_isRecordMode || !_canAnimate) return;
    final from = _displayWord;
    final to = _showingRecordWindow
        ? ActivityMechanicalCounterTitle.word
        : ActivityMechanicalCounterTitle._recordWindow;
    setState(() {
      _recordIndexing = true;
      _plans = [
        for (
          var index = 0;
          index < ActivityMechanicalCounterTitle.cellCount;
          index++
        )
          _CounterMotionPlan.registration(from: from[index], to: to[index]),
      ];
      _controller.duration =
          ActivityMechanicalCounterTitle.initialIndexDuration;
    });
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entryEventTimer?.cancel();
    _recordTransitionTimer?.cancel();
    _controller
      ..removeStatusListener(_handleMotionStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(5);
    return Semantics(
      label: widget.title,
      child: ExcludeSemantics(
        child: SizedBox(
          key: const ValueKey('activity-mechanical-counter-title'),
          width: ActivityMechanicalCounterTitle.width,
          height: ActivityMechanicalCounterTitle.height,
          child: DecoratedBox(
            key: const ValueKey('activity-mechanical-counter-title-glass'),
            decoration: DashboardGlassCard.decoration(
              Theme.of(context).colorScheme,
              borderRadius: borderRadius,
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Row(
                children: [
                  for (
                    var index = 0;
                    index < ActivityMechanicalCounterTitle.cellCount;
                    index++
                  )
                    Expanded(
                      child: _MechanicalCounterCell(
                        key: ValueKey('activity-counter-cell-$index'),
                        character: _displayWord[index],
                        index: index,
                        animation: _controller,
                        plan: _plans[index],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _CounterMotionKind { initial, periodic, registration }

class _CounterMotionPlan {
  const _CounterMotionPlan._(this.kind, this.detents, {this.from, this.to});

  factory _CounterMotionPlan.initial({required int detents}) =>
      _CounterMotionPlan._(_CounterMotionKind.initial, detents);
  factory _CounterMotionPlan.periodic({required int detents}) =>
      _CounterMotionPlan._(_CounterMotionKind.periodic, detents);
  factory _CounterMotionPlan.registration({
    required String from,
    required String to,
  }) => _CounterMotionPlan._(
    _CounterMotionKind.registration,
    _registrationDetents(from, to),
    from: from,
    to: to,
  );

  static int _registrationDetents(String from, String to) {
    if (from == ' ' || to == ' ') return 1;
    final distance = (to.codeUnitAt(0) - from.codeUnitAt(0) + 26) % 26;
    return max(1, distance);
  }

  final _CounterMotionKind kind;
  final int detents;
  final String? from;
  final String? to;
}

class _MechanicalCounterCell extends StatelessWidget {
  const _MechanicalCounterCell({
    super.key,
    required this.character,
    required this.index,
    required this.animation,
    required this.plan,
  });

  final String character;
  final int index;
  final Animation<double> animation;
  final _CounterMotionPlan? plan;

  String _offsetCharacter(int offset) {
    final base = character.codeUnitAt(0) - 65;
    final normalized = (base + offset) % 26;
    return String.fromCharCode(
      65 + (normalized < 0 ? normalized + 26 : normalized),
    );
  }

  double _cellProgress() {
    final currentPlan = plan;
    if (currentPlan == null) return 1;
    if (currentPlan.kind == _CounterMotionKind.periodic) {
      return Curves.easeInOutCubic.transform(animation.value);
    }
    final start = index * .085;
    return Curves.easeInOutCubic.transform(
      ((animation.value - start) / .29).clamp(0.0, 1.0),
    );
  }

  _DrumStep _drumStep(double progress) {
    final currentPlan = plan!;
    if (currentPlan.kind == _CounterMotionKind.registration) {
      final from = currentPlan.from!;
      final to = currentPlan.to!;
      if (from == ' ' || to == ' ') {
        return _DrumStep(
          from: from,
          to: to,
          progress: _detentProgress(progress),
        );
      }
      final scaled = progress * currentPlan.detents;
      final completed = scaled.floor().clamp(0, currentPlan.detents - 1);
      return _DrumStep(
        from: _registerCharacter(from, completed),
        to: completed == currentPlan.detents - 1
            ? to
            : _registerCharacter(from, completed + 1),
        progress: _detentProgress(scaled - scaled.floor()),
      );
    }
    if (currentPlan.kind == _CounterMotionKind.initial) {
      final scaled = progress * currentPlan.detents;
      final completed = scaled.floor().clamp(0, currentPlan.detents - 1);
      return _DrumStep(
        from: _offsetCharacter(completed - currentPlan.detents),
        to: _offsetCharacter(completed - currentPlan.detents + 1),
        progress: _detentProgress(scaled - scaled.floor()),
      );
    }
    final stages = currentPlan.detents + 1;
    final scaled = progress * stages;
    final completed = scaled.floor().clamp(0, stages - 1);
    final isReturn = completed == stages - 1;
    return _DrumStep(
      from: isReturn
          ? _offsetCharacter(currentPlan.detents)
          : _offsetCharacter(completed),
      to: isReturn ? character : _offsetCharacter(completed + 1),
      progress: _detentProgress(scaled - scaled.floor()),
    );
  }

  String _registerCharacter(String from, int detent) {
    final base = from.codeUnitAt(0) - 65;
    return String.fromCharCode(65 + (base + detent) % 26);
  }

  /// Keeps each indexed character legible at its registered detent before
  /// the drum moves it through the narrow viewport aperture.
  double _detentProgress(double value) {
    const lockFraction = .18;
    const travelFraction = 1 - lockFraction * 2;
    if (value <= lockFraction) return 0;
    if (value >= 1 - lockFraction) return 1;
    return Curves.easeInOutCubic.transform(
      (value - lockFraction) / travelFraction,
    );
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Color(0xFFF0EEE4),
      fontFamily: 'ShareTechMono',
      fontSize: 19,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacing: -.4,
      shadows: [Shadow(color: Color(0x33000000), offset: Offset(0, 1))],
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final currentPlan = plan;
        final progress = _cellProgress();
        final indexing = currentPlan != null && progress < 1;
        return Container(
          key: ValueKey('activity-counter-window-$index'),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF171A1C), Color(0xFF282C2E), Color(0xFF151719)],
              stops: [0, .5, 1],
            ),
            border: Border(
              right: index == ActivityMechanicalCounterTitle.cellCount - 1
                  ? BorderSide.none
                  : const BorderSide(color: Color(0xFF4A5054), width: .55),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportHeight = constraints.maxHeight * .66;
              final travel = viewportHeight;
              final step = indexing ? _drumStep(progress) : null;
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
                      height: viewportHeight,
                      child: ClipRect(
                        key: ValueKey('activity-counter-viewport-$index'),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (step != null)
                              Transform.translate(
                                key: ValueKey(_motionKey(currentPlan!.kind)),
                                offset: Offset(0, -travel * step.progress),
                                child: Center(
                                  child: _DrumGlyph(
                                    character: step.from,
                                    style: textStyle,
                                  ),
                                ),
                              ),
                            Transform.translate(
                              offset: Offset(
                                0,
                                step == null ? 0 : travel * (1 - step.progress),
                              ),
                              child: Center(
                                child: _DrumGlyph(
                                  character: step?.to ?? character,
                                  key: ValueKey(
                                    'activity-counter-character-$index',
                                  ),
                                  style: textStyle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0x33757B7D), width: .6),
                          bottom: BorderSide(
                            color: Color(0x99000000),
                            width: .8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _motionKey(_CounterMotionKind kind) => switch (kind) {
    _CounterMotionKind.initial => 'activity-counter-indexing-$index',
    _CounterMotionKind.periodic => 'activity-counter-periodic-$index',
    _CounterMotionKind.registration => 'activity-counter-registering-$index',
  };
}

class _DrumGlyph extends StatelessWidget {
  const _DrumGlyph({super.key, required this.character, required this.style});

  final String character;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => character == ' '
      ? const SizedBox.shrink()
      : Text(character, style: style);
}

class _DrumStep {
  const _DrumStep({
    required this.from,
    required this.to,
    required this.progress,
  });

  final String from;
  final String to;
  final double progress;
}
