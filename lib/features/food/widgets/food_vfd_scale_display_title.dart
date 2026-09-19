import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

enum FoodVfdScaleDisplayMode { normal, entry }

/// The shared FOOD AppBar instrument display. Its self-test is presentation
/// only and intentionally has no connection to Food state or measurements.
class FoodVfdScaleDisplayTitle extends StatefulWidget {
  const FoodVfdScaleDisplayTitle({
    super.key,
    this.mode = FoodVfdScaleDisplayMode.normal,
    this.entryEventMinDelay = const Duration(seconds: 10),
    this.entryEventMaxDelay = const Duration(seconds: 20),
    this.nextInt,
  });

  static const width = 134.0;
  static const height = 35.0;
  static const v14GlyphWidthFactor = .64;
  static const activeGlyphWidthFactor = .52;
  static const activeGlyphHeightFactor = .68;
  static const selfTestDuration = Duration(milliseconds: 760);
  static const periodicEventDuration = Duration(milliseconds: 800);
  static const settledInactiveSegmentOpacity = .04;
  static const selfTestInactiveSegmentOpacity = .17;

  final FoodVfdScaleDisplayMode mode;
  final Duration entryEventMinDelay;
  final Duration entryEventMaxDelay;

  /// Test injection only; production uses a local bounded random source for
  /// the ENTRY-only VFD re-energization interval.
  final int Function(int max)? nextInt;

  @override
  State<FoodVfdScaleDisplayTitle> createState() =>
      _FoodVfdScaleDisplayTitleState();
}

class _FoodVfdScaleDisplayTitleState extends State<FoodVfdScaleDisplayTitle>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _selfTestController;
  late final AnimationController _entryEventController;
  final Random _random = Random();
  Timer? _entryEventTimer;
  bool _selfTestRequested = false;
  bool _selfTestCompleted = false;
  bool _entryEventActive = false;
  bool _motionEnabled = true;
  bool _appActive = true;
  int _nextDropoutPattern = 0;
  List<int> _activeDropoutPattern = const [0, 1, 2, 3];

  static const _dropoutPatterns = <List<int>>[
    [0, 1, 2, 3],
    [3, 2, 1, 0],
    [1, 3, 0, 2],
    [2, 0, 3, 1],
  ];

  bool get _isEntry => widget.mode == FoodVfdScaleDisplayMode.entry;
  bool get _canAnimate =>
      _motionEnabled && _appActive && TickerMode.valuesOf(context).enabled;
  int _nextInt(int max) => widget.nextInt?.call(max) ?? _random.nextInt(max);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selfTestController = AnimationController(
      vsync: this,
      duration: FoodVfdScaleDisplayTitle.selfTestDuration,
    )..addStatusListener(_handleSelfTestStatus);
    _entryEventController = AnimationController(
      vsync: this,
      duration: FoodVfdScaleDisplayTitle.periodicEventDuration,
    )..addStatusListener(_handleEntryEventStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _selfTestController.value = 1;
      _entryEventController.value = 0;
      _entryEventTimer?.cancel();
      _selfTestCompleted = true;
      _entryEventActive = false;
      _motionEnabled = false;
      return;
    }
    _motionEnabled = true;
    if (!_canAnimate) {
      _entryEventTimer?.cancel();
      _entryEventController.stop();
      _entryEventActive = false;
      return;
    }
    if (!_selfTestRequested) {
      _selfTestRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _canAnimate) _selfTestController.forward();
      });
    } else if (_selfTestCompleted &&
        _isEntry &&
        !_entryEventActive &&
        _entryEventTimer == null) {
      _scheduleEntryEvent();
    }
  }

  @override
  void didUpdateWidget(covariant FoodVfdScaleDisplayTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode == widget.mode) return;
    _entryEventTimer?.cancel();
    if (!_isEntry) {
      _entryEventController
        ..stop()
        ..value = 0;
      _entryEventActive = false;
      return;
    }
    if (_isEntry && _selfTestCompleted && _canAnimate) {
      _scheduleEntryEvent();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_appActive == active) return;
    _appActive = active;
    if (!active) {
      _entryEventTimer?.cancel();
      _entryEventController
        ..stop()
        ..value = 0;
      _entryEventActive = false;
      return;
    }
    if (_canAnimate && _selfTestCompleted && _isEntry) {
      _scheduleEntryEvent();
    }
  }

  void _handleSelfTestStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _selfTestCompleted = true;
    _scheduleEntryEvent();
  }

  void _handleEntryEventStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() {
      _entryEventActive = false;
      _entryEventController.value = 0;
    });
    _scheduleEntryEvent();
  }

  void _scheduleEntryEvent() {
    if (!_isEntry || !_selfTestCompleted || !_canAnimate) return;
    if (_entryEventActive || _entryEventController.isAnimating) return;
    _entryEventTimer?.cancel();
    final minimum = widget.entryEventMinDelay.inMilliseconds;
    final maximum = widget.entryEventMaxDelay.inMilliseconds;
    final delay = minimum + _nextInt(maximum - minimum + 1);
    _entryEventTimer = Timer(Duration(milliseconds: delay), _beginEntryEvent);
  }

  void _beginEntryEvent() {
    _entryEventTimer = null;
    if (!mounted ||
        !_isEntry ||
        !_canAnimate ||
        _entryEventActive ||
        _entryEventController.isAnimating) {
      return;
    }
    setState(() {
      _entryEventActive = true;
      _activeDropoutPattern = _dropoutPatterns[_nextDropoutPattern];
      _nextDropoutPattern = (_nextDropoutPattern + 1) % _dropoutPatterns.length;
    });
    _entryEventController.forward(from: 0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entryEventTimer?.cancel();
    _selfTestController
      ..removeStatusListener(_handleSelfTestStatus)
      ..dispose();
    _entryEventController
      ..removeStatusListener(_handleEntryEventStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'FOOD',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            key: const ValueKey('food-vfd-scale-title'),
            width: FoodVfdScaleDisplayTitle.width,
            height: FoodVfdScaleDisplayTitle.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF12191A),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: const Color(0xFF536568), width: .8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ClipRRect(
                  key: const ValueKey('food-vfd-glass'),
                  borderRadius: BorderRadius.circular(1.5),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF102426),
                          Color(0xFF071113),
                          Color(0xFF050A0B),
                        ],
                        stops: [0, .5, 1],
                      ),
                    ),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _selfTestController,
                        _entryEventController,
                      ]),
                      builder: (context, _) => Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(
                            key: const ValueKey('food-vfd-inactive-structure'),
                            painter: _FoodVfdDisplayPainter(
                              selfTest: _selfTestController.value,
                              entryEvent: _entryEventController.value,
                              dropoutPattern: _activeDropoutPattern,
                            ),
                          ),
                          if (_selfTestController.value < 1)
                            const SizedBox(key: ValueKey('food-vfd-self-test')),
                          if (_entryEventActive)
                            const SizedBox(
                              key: ValueKey('food-vfd-entry-event'),
                            ),
                          if (_entryEventActive)
                            ..._VfdDriverDropout.from(
                              _entryEventController.value,
                              _activeDropoutPattern,
                            ).offCharacters.map(
                              (index) => SizedBox(
                                key: ValueKey('food-vfd-driver-off-$index'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FoodVfdDisplayPainter extends CustomPainter {
  const _FoodVfdDisplayPainter({
    required this.selfTest,
    required this.entryEvent,
    required this.dropoutPattern,
  });

  final double selfTest;
  final double entryEvent;
  final List<int> dropoutPattern;

  @override
  void paint(Canvas canvas, Size size) {
    const glyphs = ['F', 'O', 'O', 'D'];
    const inactive = Color(0xFF55B5A7);
    const bloom = Color(0x4539E0C7);
    const active = Color(0xFF78E9D5);
    final phase = ((selfTest - .3) / .55).clamp(0.0, 1.0);
    final structureReveal = Curves.easeOut.transform(
      ((selfTest - .1) / .2).clamp(0.0, 1.0),
    );
    final structureSettle = Curves.easeIn.transform(
      ((selfTest - .38) / .25).clamp(0.0, 1.0),
    );
    final structureOpacity =
        FoodVfdScaleDisplayTitle.settledInactiveSegmentOpacity +
        (FoodVfdScaleDisplayTitle.selfTestInactiveSegmentOpacity -
                FoodVfdScaleDisplayTitle.settledInactiveSegmentOpacity) *
            structureReveal *
            (1 - structureSettle);
    final dropout = _VfdDriverDropout.from(entryEvent, dropoutPattern);
    final cellWidth = size.width / glyphs.length;
    final glyphHeight =
        size.height * FoodVfdScaleDisplayTitle.activeGlyphHeightFactor;
    final glyphTop = (size.height - glyphHeight) / 2;
    final glyphWidth =
        cellWidth * FoodVfdScaleDisplayTitle.activeGlyphWidthFactor;

    for (var index = 0; index < glyphs.length; index++) {
      final rect = Rect.fromLTWH(
        index * cellWidth + (cellWidth - glyphWidth) / 2,
        glyphTop,
        glyphWidth,
        glyphHeight,
      );
      final allSegments = _inactiveSegments(rect);
      for (final segment in allSegments) {
        canvas.drawPath(
          segment,
          Paint()..color = inactive.withValues(alpha: structureOpacity),
        );
      }
      final glyphProgress = (phase * glyphs.length - index).clamp(0.0, 1.0);
      if (glyphProgress == 0) continue;
      final opacity = Curves.easeOut.transform(glyphProgress);
      for (final segment in _activeGlyphPaths(glyphs[index], rect)) {
        canvas.drawPath(
          segment,
          Paint()
            ..color = bloom.withValues(
              alpha: opacity * dropout.emissionFor(index),
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
        );
        canvas.drawPath(
          segment,
          Paint()
            ..color = active.withValues(
              alpha: opacity * dropout.emissionFor(index),
            ),
        );
      }
    }
  }

  List<Path> _inactiveSegments(Rect rect) {
    final segments = <String, Path>{
      'a': _horizontal(rect.left, rect.top, rect.width),
      'b': _diagonal(rect.right - rect.width * .18, rect.top, rect.height / 2),
      'c': _diagonal(
        rect.right - rect.width * .18,
        rect.center.dy,
        rect.height / 2,
      ),
      'd': _horizontal(rect.left, rect.bottom - rect.height * .12, rect.width),
      'e': _vertical(rect.left, rect.center.dy, rect.height / 2),
      'f': _vertical(rect.left, rect.top, rect.height / 2),
      'g': _horizontal(
        rect.left,
        rect.center.dy - rect.height * .06,
        rect.width * .72,
      ),
    };
    return segments.values.toList(growable: false);
  }

  List<Path> _activeGlyphPaths(String glyph, Rect rect) => switch (glyph) {
    'F' => [
      _vfdStem(rect.left, rect.top, rect.height, thickness: 2.15),
      _horizontal(rect.left, rect.top, rect.width * .92),
      _horizontal(rect.left, rect.center.dy - .85, rect.width * .76),
    ],
    'O' => [_chamferedLoop(rect)],
    'D' => [_classicD(rect)],
    _ => const [],
  };

  Path _chamferedLoop(Rect rect) {
    const stroke = 1.65;
    final outer = _octagon(rect, inset: 0);
    final inner = _octagon(rect.deflate(stroke), inset: 0);
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPolygon(outer, true)
      ..addPolygon(inner, true);
  }

  Path _classicD(Rect rect) {
    const stemWidth = 2.55;
    const bowlStroke = 1.6;
    final chamfer = (rect.width * .18).clamp(1.4, 2.8).toDouble();
    final outer = <Offset>[
      Offset(rect.left, rect.top),
      Offset(rect.right - chamfer, rect.top),
      Offset(rect.right, rect.top + chamfer),
      Offset(rect.right, rect.bottom - chamfer),
      Offset(rect.right - chamfer, rect.bottom),
      Offset(rect.left, rect.bottom),
    ];
    final inner = <Offset>[
      Offset(rect.left + stemWidth, rect.top + bowlStroke),
      Offset(rect.right - chamfer, rect.top + bowlStroke),
      Offset(rect.right - bowlStroke, rect.top + chamfer),
      Offset(rect.right - bowlStroke, rect.bottom - chamfer),
      Offset(rect.right - chamfer, rect.bottom - bowlStroke),
      Offset(rect.left + stemWidth, rect.bottom - bowlStroke),
    ];
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPolygon(outer, true)
      ..addPolygon(inner, true);
  }

  List<Offset> _octagon(Rect rect, {required double inset}) {
    final chamfer = ((rect.width * .17).clamp(1.5, 3.2) + inset * .15)
        .toDouble();
    return [
      Offset(rect.left + chamfer, rect.top),
      Offset(rect.right - chamfer, rect.top),
      Offset(rect.right, rect.top + chamfer),
      Offset(rect.right, rect.bottom - chamfer),
      Offset(rect.right - chamfer, rect.bottom),
      Offset(rect.left + chamfer, rect.bottom),
      Offset(rect.left, rect.bottom - chamfer),
      Offset(rect.left, rect.top + chamfer),
    ];
  }

  Path _vfdStem(
    double left,
    double top,
    double height, {
    required double thickness,
  }) {
    const bevel = 1.15;
    return Path()
      ..moveTo(left, top + bevel)
      ..lineTo(left + thickness / 2, top)
      ..lineTo(left + thickness, top + bevel)
      ..lineTo(left + thickness, top + height - bevel)
      ..lineTo(left + thickness / 2, top + height)
      ..lineTo(left, top + height - bevel)
      ..close();
  }

  Path _horizontal(double left, double top, double width) {
    const thickness = 1.7;
    const bevel = 1.5;
    return Path()
      ..moveTo(left + bevel, top)
      ..lineTo(left + width - bevel, top)
      ..lineTo(left + width, top + thickness / 2)
      ..lineTo(left + width - bevel, top + thickness)
      ..lineTo(left + bevel, top + thickness)
      ..lineTo(left, top + thickness / 2)
      ..close();
  }

  Path _vertical(double left, double top, double height) {
    const thickness = 1.7;
    const bevel = 1.3;
    return Path()
      ..moveTo(left, top + bevel)
      ..lineTo(left + thickness / 2, top)
      ..lineTo(left + thickness, top + bevel)
      ..lineTo(left + thickness, top + height - bevel)
      ..lineTo(left + thickness / 2, top + height)
      ..lineTo(left, top + height - bevel)
      ..close();
  }

  Path _diagonal(double left, double top, double height) {
    const thickness = 1.7;
    return Path()
      ..moveTo(left, top + 1)
      ..lineTo(left + thickness, top)
      ..lineTo(left + thickness, top + height - 1)
      ..lineTo(left, top + height)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _FoodVfdDisplayPainter oldDelegate) =>
      oldDelegate.selfTest != selfTest ||
      oldDelegate.entryEvent != entryEvent ||
      oldDelegate.dropoutPattern != dropoutPattern;
}

class _VfdDriverDropout {
  const _VfdDriverDropout._(this.offCharacters, this._emissions);

  factory _VfdDriverDropout.from(double value, List<int> pattern) {
    final emissions = List<double>.filled(4, 1);
    final offCharacters = <int>[];
    for (var order = 0; order < pattern.length; order++) {
      final character = pattern[order];
      final start = .04 + order * .22;
      final local = ((value - start) / .16).clamp(0.0, 1.0);
      if (value < start || local >= 1) continue;
      final emission = switch (local) {
        < .22 => 1 - Curves.easeInCubic.transform(local / .22),
        < .76 => 0.0,
        _ => Curves.easeOutCubic.transform((local - .76) / .24),
      };
      emissions[character] = emission;
      if (emission < .02) offCharacters.add(character);
    }
    return _VfdDriverDropout._(offCharacters, emissions);
  }

  final List<int> offCharacters;
  final List<double> _emissions;

  double emissionFor(int index) => _emissions[index];
}

/// Explicit active geometry for the readable custom VFD alphabet. The
/// inactive electrode field remains intentionally separate from these paths.
class FoodVfdGlyphGeometry {
  const FoodVfdGlyphGeometry._();

  static const f = <String>['leftStem', 'topBar', 'middleBar'];
  static const o = <String>['chamferedLoop', 'openCounter'];
  static const d = <String>[
    'structuralLeftStem',
    'continuousRightBowl',
    'openCounter',
  ];

  static List<String> activeSegmentsFor(String glyph) => switch (glyph) {
    'F' => f,
    'O' => o,
    'D' => d,
    _ => const [],
  };
}
