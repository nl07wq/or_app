import 'package:flutter/material.dart';

import '../../../core/services/device_settings_controller.dart';

/// Command Center-only industrial glyph Data Rain.
///
/// The painter uses a compact programmatic 5×7 atlas instead of a platform
/// font. Glyph sequences are generated once per stream recycle, then remain
/// fixed while their columns move at a constant speed.
class CommandCenterAmbientProcessing extends StatefulWidget {
  const CommandCenterAmbientProcessing({
    super.key,
    required this.enabled,
    this.midRearDensity = CommandCenterMidRearDensity.low,
    @visibleForTesting this.debugOnlyLayer,
  });

  static const rootKey = ValueKey('command-center-ambient-processing');
  static const foregroundKey = ValueKey('command-center-data-rain-foreground');
  static const midFrontKey = ValueKey('command-center-data-rain-mid-front');
  static const midRearKey = ValueKey('command-center-data-rain-mid-rear');

  static const foregroundColumnsAt390 = 30;
  static const midFrontColumnsAt390 = 33;
  static const midRearColumnsAt390 = 12;
  static const midRearMediumColumnsAt390 = 21;
  static const midRearHighColumnsAt390 = 31;
  static const totalColumnsAt390 =
      foregroundColumnsAt390 + midFrontColumnsAt390 + midRearColumnsAt390;
  static const leftColumnsAt390 = 32;
  static const centerColumnsAt390 = 11;
  static const rightColumnsAt390 = 32;

  /// The repeating 20-slot library gives exactly 45% letters, 25% numbers,
  /// and 30% technical symbols before its deterministic stream offset.
  static const glyphCategoryPeriod = 20;
  static const letterSlotsPerPeriod = 9;
  static const numberSlotsPerPeriod = 5;
  static const symbolSlotsPerPeriod = 6;

  /// V2.2 uses 65% of the original V2 dot-matrix geometry.  Every visible
  /// glyph measurement derives from this one scale so the painter, pitch and
  /// layer relationship cannot accidentally diverge.
  static const glyphScale = .65;
  static const longStreamsPerPeriod = 15;
  static const mediumStreamsPerPeriod = 4;
  static const shortStreamsPerPeriod = 1;
  static const sharedPatternCount = 16;

  static final Map<DataRainLayer, DataRainPaintMetrics> _debugPaintMetrics =
      <DataRainLayer, DataRainPaintMetrics>{};

  /// Available only to tests running with assertions. This keeps production
  /// paint loops free of instrumentation allocation and mutation.
  @visibleForTesting
  static DataRainPaintMetrics? debugPaintMetricsFor(DataRainLayer layer) =>
      _debugPaintMetrics[layer];

  /// Immutable, shared 48-glyph industrial patterns. Streams retain a pattern
  /// reference instead of allocating a glyph list from inside paint().
  static final List<List<String>> sharedPatterns = List.unmodifiable(
    List<List<String>>.generate(
      sharedPatternCount,
      (pattern) => List.unmodifiable(
        List<String>.generate(
          48,
          (position) => _IndustrialGlyphAtlas.glyphFor(pattern * 101, position),
          growable: false,
        ),
      ),
      growable: false,
    ),
  );

  final bool enabled;
  final CommandCenterMidRearDensity midRearDensity;

  /// Lets production-painter tests capture exactly one depth layer. Normal
  /// application construction leaves this null and paints all three layers.
  @visibleForTesting
  final DataRainLayer? debugOnlyLayer;

  /// Constant linear movement. A stream never eases between recycle points.
  static double constantSpeedOffset({
    required double elapsed,
    required double pixelsPerSecond,
  }) => elapsed * pixelsPerSecond;

  static const speeds = <DataRainSpeed, double>{
    DataRainSpeed.slow: 12,
    DataRainSpeed.normal: 22,
    DataRainSpeed.fast: 38,
    DataRainSpeed.burst: 60,
  };

  static int midRearColumnsAt390For(CommandCenterMidRearDensity density) =>
      density.streamsAt390;

  static int columnsAt390For({
    required DataRainLayer layer,
    required CommandCenterMidRearDensity midRearDensity,
  }) => switch (layer) {
    DataRainLayer.foreground => foregroundColumnsAt390,
    DataRainLayer.midFront => midFrontColumnsAt390,
    DataRainLayer.midRear => midRearColumnsAt390For(midRearDensity),
  };

  static int columnsFor({
    required DataRainLayer layer,
    required double width,
    required CommandCenterMidRearDensity midRearDensity,
  }) =>
      (columnsAt390For(layer: layer, midRearDensity: midRearDensity) *
              (width / 390).clamp(.82, 1.45))
          .round();

  static int totalColumnsFor(
    double width, {
    CommandCenterMidRearDensity midRearDensity =
        CommandCenterMidRearDensity.low,
  }) => DataRainLayer.values.fold(
    0,
    (total, layer) =>
        total +
        columnsFor(layer: layer, width: width, midRearDensity: midRearDensity),
  );

  static List<DataRainStreamPlacement> streamPlacementsFor({
    required DataRainLayer layer,
    required double width,
    CommandCenterMidRearDensity midRearDensity =
        CommandCenterMidRearDensity.low,
  }) {
    final total = columnsFor(
      layer: layer,
      width: width,
      midRearDensity: midRearDensity,
    );
    final side = (total * leftColumnsAt390 / totalColumnsAt390).round();
    final bands = [side, total - side * 2, side];
    var index = 0;
    final result = <DataRainStreamPlacement>[];
    for (var band = 0; band < bands.length; band++) {
      final count = bands[band];
      for (var i = 0; i < count; i++) {
        result.add(
          DataRainStreamPlacement(
            band: DataRainHorizontalBand.values[band],
            bandIndex: i,
            bandCount: count,
            streamIndex: index++,
          ),
        );
      }
    }
    return result;
  }

  static double placementXFraction({
    required DataRainLayer layer,
    required DataRainStreamPlacement placement,
  }) {
    const bounds = [(.0, .36), (.29, .71), (.64, 1.0)];
    final range = bounds[placement.band.index];
    final slot = (placement.bandIndex + .5) / placement.bandCount;
    final jitter =
        ((_hash(placement.streamIndex, 17 + layer.index * 19) % 1000) / 1000 -
            .5) *
        1.1 /
        placement.bandCount;
    return (range.$1 + (range.$2 - range.$1) * (slot + jitter)).clamp(
      .006,
      .994,
    );
  }

  static double glyphSizeFor(DataRainLayer layer) =>
      switch (layer) {
        DataRainLayer.foreground => 8.0,
        DataRainLayer.midFront => 4.8,
        // MID-REAR remains derived from the MID-FRONT geometry, rather than
        // reviving the too-small V2.8 background cells.
        DataRainLayer.midRear => 4.8 * .78,
      } *
      glyphScale;

  static double glyphDotSizeFor(DataRainLayer layer) =>
      glyphSizeFor(layer) * .15;

  static double glyphDotPitchFor(DataRainLayer layer) =>
      glyphDotSizeFor(layer) * 1.45;

  static double glyphVerticalPitchFor(DataRainLayer layer) =>
      glyphSizeFor(layer) *
      switch (layer) {
        DataRainLayer.foreground => 1.52,
        DataRainLayer.midFront => 1.72,
        DataRainLayer.midRear => 1.72,
      };

  /// MID-REAR reuses the MID-FRONT grid, but paints each position as one
  /// lighter discrete data segment rather than a 5×7 glyph path.
  static double get midRearSegmentWidth =>
      glyphSizeFor(DataRainLayer.midFront) * .78;

  static double get midRearSegmentStrokeWidth =>
      glyphDotSizeFor(DataRainLayer.midFront) * .78;

  /// Every moving session begins with the lead glyph above the viewport. The
  /// deterministic delay spreads physical top-down arrivals without changing
  /// a stream's assigned speed or requiring a second startup timeline.
  static double initialEntryHeadFor({
    required DataRainLayer layer,
    required int streamIndex,
  }) =>
      -glyphSizeFor(layer) -
      (_hash(streamIndex, 211 + layer.index * 37) % 1000) / 1000 * 96;

  /// Exposed for deterministic regression coverage of the generated library.
  static List<String> glyphSequenceForStream({
    required DataRainLayer layer,
    required int streamIndex,
    required int recycleIndex,
    required int length,
  }) {
    final seed = _streamSeed(layer, streamIndex, recycleIndex);
    return List<String>.generate(
      length,
      (position) => _IndustrialGlyphAtlas.glyphFor(seed, position),
      growable: false,
    );
  }

  static DataRainGlyphCategory glyphCategoryFor(String glyph) {
    if (glyph.codeUnitAt(0) >= 65 && glyph.codeUnitAt(0) <= 90) {
      return DataRainGlyphCategory.letter;
    }
    if (glyph.codeUnitAt(0) >= 48 && glyph.codeUnitAt(0) <= 57) {
      return DataRainGlyphCategory.number;
    }
    return DataRainGlyphCategory.symbol;
  }

  /// Layers deliberately use separate jittered grids, permitting real X-axis
  /// overlap rather than reserving mutually exclusive column slots.
  static double columnXFraction({
    required DataRainLayer layer,
    required int streamIndex,
    required int count,
  }) {
    final slot = (streamIndex + .5) / count;
    final jitter =
        ((_hash(streamIndex, 17 + layer.index * 19) % 1000) / 1000 - .5) *
        1.28 /
        count;
    return (slot + jitter).clamp(.006, .994);
  }

  static DataRainPulseDirection pulseDirectionForStream({
    required DataRainLayer layer,
    required int streamIndex,
  }) => _hash(streamIndex, 107 + layer.index * 13).isEven
      ? DataRainPulseDirection.downward
      : DataRainPulseDirection.upward;

  static DataRainStreamLength streamLengthFor({
    required DataRainLayer layer,
    required int streamIndex,
  }) {
    final slot = (streamIndex * 7 + layer.index * 5) % 20;
    if (slot < longStreamsPerPeriod) return DataRainStreamLength.long;
    if (slot < longStreamsPerPeriod + mediumStreamsPerPeriod) {
      return DataRainStreamLength.medium;
    }
    return DataRainStreamLength.short;
  }

  static int _streamSeed(
    DataRainLayer layer,
    int streamIndex,
    int recycleIndex,
  ) => _hash(streamIndex + recycleIndex * 101, 83 + layer.index * 31);

  static int _hash(int value, int salt) =>
      (value * salt * 1103515245 + 12345) & 0x7fffffff;

  @override
  State<CommandCenterAmbientProcessing> createState() =>
      _CommandCenterAmbientProcessingState();
}

enum DataRainSpeed { slow, normal, fast, burst }

enum DataRainLayer { foreground, midFront, midRear }

enum DataRainGlyphCategory { letter, number, symbol }

enum DataRainPulseDirection { upward, downward }

enum DataRainStreamLength { long, medium, short }

enum DataRainHorizontalBand { left, center, right }

/// Debug-only paint counters for equivalent renderer comparisons. Production
/// builds do not create or update these values because every mutation lives in
/// an assert callback.
@immutable
class DataRainPaintMetrics {
  const DataRainPaintMetrics({
    required this.activeStreams,
    required this.streamIdentitySignature,
    required this.offscreenStreams,
    required this.visibleCells,
    required this.glyphDrawAttempts,
    required this.segmentDrawAttempts,
    required this.canvasTransforms,
  });

  final int activeStreams;

  /// Debug-only identity checksum used to prove that a MID-REAR density change
  /// does not replace foreground or MID-FRONT stream metadata.
  final int streamIdentitySignature;
  final int offscreenStreams;
  final int visibleCells;
  final int glyphDrawAttempts;
  final int segmentDrawAttempts;
  final int canvasTransforms;
}

class _DataRainPaintMetricsBuilder {
  _DataRainPaintMetricsBuilder(List<_PersistentDataRainStream> streams)
    : activeStreams = streams.length,
      streamIdentitySignature = Object.hashAll(streams.map(identityHashCode));

  final int activeStreams;
  final int streamIdentitySignature;
  var offscreenStreams = 0;
  var visibleCells = 0;
  var glyphDrawAttempts = 0;
  var segmentDrawAttempts = 0;
  var canvasTransforms = 0;

  DataRainPaintMetrics build() => DataRainPaintMetrics(
    activeStreams: activeStreams,
    streamIdentitySignature: streamIdentitySignature,
    offscreenStreams: offscreenStreams,
    visibleCells: visibleCells,
    glyphDrawAttempts: glyphDrawAttempts,
    segmentDrawAttempts: segmentDrawAttempts,
    canvasTransforms: canvasTransforms,
  );
}

@immutable
class DataRainStreamPlacement {
  const DataRainStreamPlacement({
    required this.band,
    required this.bandIndex,
    required this.bandCount,
    required this.streamIndex,
  });
  final DataRainHorizontalBand band;
  final int bandIndex;
  final int bandCount;
  final int streamIndex;
}

@immutable
class _PersistentDataRainStream {
  const _PersistentDataRainStream({
    required this.streamIndex,
    required this.xFraction,
    required this.length,
    required this.speed,
    required this.pattern,
  });

  factory _PersistentDataRainStream.create({
    required DataRainLayer layer,
    required DataRainStreamPlacement placement,
    required double height,
    required double glyphSize,
    required double step,
  }) {
    final streamIndex = placement.streamIndex;
    final kind = CommandCenterAmbientProcessing.streamLengthFor(
      layer: layer,
      streamIndex: streamIndex,
    );
    final variation =
        CommandCenterAmbientProcessing._hash(
          streamIndex,
          191 + layer.index * 23,
        ) %
        1000 /
        1000;
    final fraction = switch (kind) {
      DataRainStreamLength.long => .26 + variation * .18,
      DataRainStreamLength.medium => .12 + variation * .09,
      DataRainStreamLength.short => .055 + variation * .045,
    };
    return _PersistentDataRainStream(
      streamIndex: streamIndex,
      xFraction: CommandCenterAmbientProcessing.placementXFraction(
        layer: layer,
        placement: placement,
      ),
      length: (height * fraction / step).round().clamp(4, 42),
      speed:
          DataRainSpeed.values[CommandCenterAmbientProcessing._hash(
                streamIndex,
                29 + layer.index * 7,
              ) %
              DataRainSpeed.values.length],
      pattern:
          CommandCenterAmbientProcessing
              .sharedPatterns[CommandCenterAmbientProcessing._hash(
                streamIndex,
                211 + layer.index * 41,
              ) %
              CommandCenterAmbientProcessing.sharedPatternCount],
    );
  }

  final int streamIndex;
  final double xFraction;
  final int length;
  final DataRainSpeed speed;
  final List<String> pattern;
}

class _CommandCenterAmbientProcessingState
    extends State<CommandCenterAmbientProcessing>
    with SingleTickerProviderStateMixin {
  static const _cycleDuration = Duration(seconds: 8);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycleDuration,
  );
  var _motionAllowed = false;
  var _running = false;
  var _cycle = 0;
  var _resolvedMotion = false;
  Color? _color;
  late final ValueNotifier<int> _configurationRevision = ValueNotifier(0);
  final Map<DataRainLayer, _IndustrialDataRainPainter> _painters = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final color = Theme.of(context).colorScheme.primary;
    if (_color != color) {
      _color = color;
      _bumpPainterConfiguration();
    }
    final motionAllowed =
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false) &&
        TickerMode.valuesOf(context).enabled;
    if (!_resolvedMotion || motionAllowed != _motionAllowed) {
      final startsNewSession =
          !_resolvedMotion ||
          (!_motionAllowed && motionAllowed && widget.enabled);
      _motionAllowed = motionAllowed;
      _resolvedMotion = true;
      _syncAnimation(startsNewSession: startsNewSession);
      _bumpPainterConfiguration();
    }
  }

  @override
  void didUpdateWidget(covariant CommandCenterAmbientProcessing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _syncAnimation(startsNewSession: widget.enabled);
    }
    if (oldWidget.midRearDensity != widget.midRearDensity) {
      // Only MID-REAR observes this revision. Its painter reallocates its
      // stream metadata while foreground and MID-FRONT retain their objects.
      _bumpPainterConfiguration();
    }
  }

  void _bumpPainterConfiguration() => _configurationRevision.value++;

  void _syncAnimation({required bool startsNewSession}) {
    if (!mounted) return;
    _controller.stop();
    _running = false;
    if (startsNewSession || !widget.enabled) {
      _cycle = 0;
      _controller.value = 0;
    }
    if (widget.enabled && _motionAllowed) {
      // Initial entry and steady-state use this exact controller and the same
      // linear stream equation. Only each stream's initial Y position differs.
      _startCycle();
    } else {
      _controller.value = 0;
    }
  }

  void _startCycle() {
    if (!mounted || !widget.enabled || !_motionAllowed) return;
    setState(() => _running = true);
    _controller.forward(from: 0).whenComplete(() {
      if (!mounted || !widget.enabled || !_motionAllowed) return;
      setState(() {
        _cycle++;
      });
      _startCycle();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _configurationRevision.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        key: CommandCenterAmbientProcessing.rootKey,
        child: Stack(
          fit: StackFit.expand,
          children: widget.debugOnlyLayer == null
              ? [
                  _layer(DataRainLayer.midRear),
                  _layer(DataRainLayer.midFront),
                  _layer(DataRainLayer.foreground),
                ]
              : [_layer(widget.debugOnlyLayer!)],
        ),
      ),
    );
  }

  Widget _layer(DataRainLayer layer) => CustomPaint(
    key: switch (layer) {
      DataRainLayer.foreground => CommandCenterAmbientProcessing.foregroundKey,
      DataRainLayer.midFront => CommandCenterAmbientProcessing.midFrontKey,
      DataRainLayer.midRear => CommandCenterAmbientProcessing.midRearKey,
    },
    painter: _painters.putIfAbsent(
      layer,
      () => _IndustrialDataRainPainter(
        animation: _controller,
        repaint: Listenable.merge([_controller, _configurationRevision]),
        color: () => _color ?? Colors.cyan,
        layer: layer,
        staticFrame: () => !_motionAllowed,
        running: () => _running,
        completedSeconds: () => _cycle * _cycleDuration.inMilliseconds / 1000,
        initialEntry: () => _motionAllowed,
        midRearDensity: () => widget.midRearDensity,
      ),
    ),
  );
}

class _IndustrialDataRainPainter extends CustomPainter {
  _IndustrialDataRainPainter({
    required this.animation,
    required Listenable repaint,
    required this.color,
    required this.layer,
    required this.staticFrame,
    required this.running,
    required this.completedSeconds,
    required this.initialEntry,
    required this.midRearDensity,
  }) : super(repaint: repaint);

  final Animation<double> animation;
  final Color Function() color;
  final DataRainLayer layer;
  final bool Function() staticFrame;
  final bool Function() running;
  final double Function() completedSeconds;
  final bool Function() initialEntry;
  final CommandCenterMidRearDensity Function() midRearDensity;
  final Paint _glyphPaint = Paint();
  final Paint _segmentPaint = Paint()..strokeCap = StrokeCap.square;
  Size? _streamSize;
  CommandCenterMidRearDensity? _streamDensity;
  List<_PersistentDataRainStream> _streams = const [];

  double get _seconds => staticFrame() || !running()
      ? completedSeconds()
      : completedSeconds() + animation.value * 8;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final density = midRearDensity();
    if (_streamSize != size ||
        (layer == DataRainLayer.midRear && _streamDensity != density)) {
      _streamSize = size;
      _streamDensity = density;
      _streams = _createStreams(size, density);
    }
    _DataRainPaintMetricsBuilder? metrics;
    assert(() {
      metrics = _DataRainPaintMetricsBuilder(_streams);
      return true;
    }());
    for (final stream in _streams) {
      _paintStream(canvas, size, stream, metrics, color());
    }
    assert(() {
      CommandCenterAmbientProcessing._debugPaintMetrics[layer] = metrics!
          .build();
      return true;
    }());
  }

  List<_PersistentDataRainStream> _createStreams(
    Size size,
    CommandCenterMidRearDensity density,
  ) {
    final glyphSize = CommandCenterAmbientProcessing.glyphSizeFor(layer);
    final step = CommandCenterAmbientProcessing.glyphVerticalPitchFor(layer);
    return List.unmodifiable([
      for (final placement
          in CommandCenterAmbientProcessing.streamPlacementsFor(
            layer: layer,
            width: size.width,
            midRearDensity: density,
          ))
        _PersistentDataRainStream.create(
          layer: layer,
          placement: placement,
          height: size.height,
          glyphSize: glyphSize,
          step: step,
        ),
    ]);
  }

  void _paintStream(
    Canvas canvas,
    Size size,
    _PersistentDataRainStream stream,
    _DataRainPaintMetricsBuilder? metrics,
    Color baseColor,
  ) {
    final streamIndex = stream.streamIndex;
    final glyphSize = CommandCenterAmbientProcessing.glyphSizeFor(layer);
    final step = CommandCenterAmbientProcessing.glyphVerticalPitchFor(layer);
    final length = stream.length;
    final trail = length * step;
    final span = size.height + trail;
    final travel = CommandCenterAmbientProcessing.constantSpeedOffset(
      elapsed: _seconds,
      pixelsPerSecond: CommandCenterAmbientProcessing.speeds[stream.speed]!,
    );
    final position = _streamPosition(
      size: size,
      streamIndex: streamIndex,
      glyphSize: glyphSize,
      trail: trail,
      span: span,
      travel: travel,
    );
    // A fully offscreen stream requires no glyph, pulse, color, or path work.
    if (position.head < -glyphSize ||
        position.head - trail > size.height + glyphSize) {
      assert(() {
        metrics?.offscreenStreams++;
        return true;
      }());
      return;
    }
    final x = size.width * stream.xFraction;
    for (var glyphPosition = 0; glyphPosition < length; glyphPosition++) {
      final y = position.head - glyphPosition * step;
      if (y < -glyphSize || y > size.height + glyphSize) continue;
      assert(() {
        metrics?.visibleCells++;
        return true;
      }());
      final pulse = _pulseStrength(streamIndex, glyphPosition, length);
      final baseline = switch (layer) {
        DataRainLayer.foreground => .34,
        DataRainLayer.midFront => .19,
        DataRainLayer.midRear => .11,
      };
      final alpha =
          (baseline +
                  pulse *
                      switch (layer) {
                        DataRainLayer.foreground => .53,
                        DataRainLayer.midFront => .35,
                        DataRainLayer.midRear => .22,
                      })
              .clamp(0.0, 1.0);
      final glyphColor = pulse > .08
          ? Color.lerp(baseColor, Colors.cyanAccent, .48)!
          : baseColor;
      final cellColor = glyphColor.withValues(alpha: alpha);
      if (layer == DataRainLayer.midRear) {
        assert(() {
          metrics?.segmentDrawAttempts++;
          return true;
        }());
        _paintMidRearSegment(canvas, center: Offset(x, y), color: cellColor);
      } else {
        assert(() {
          metrics?.glyphDrawAttempts++;
          metrics?.canvasTransforms++;
          return true;
        }());
        _paintGlyph(
          canvas,
          center: Offset(x, y),
          size: glyphSize,
          glyph: stream.pattern[glyphPosition % stream.pattern.length],
          color: cellColor,
        );
      }
    }
  }

  _DataRainStreamPosition _streamPosition({
    required Size size,
    required int streamIndex,
    required double glyphSize,
    required double trail,
    required double span,
    required double travel,
  }) {
    if (!initialEntry() || staticFrame()) {
      final initial =
          _hash(streamIndex, 71 + layer.index * 11) % 1000 / 1000 * span;
      final total = initial + travel;
      return _DataRainStreamPosition(
        head: total % span - trail,
        recycleIndex: total ~/ span,
      );
    }

    // A new session differs from steady-state only by this negative initial
    // position. The same stream object, constant speed and recycle path stay
    // in use while it enters and thereafter. The lead glyph and its complete
    // trail begin above the viewport; recycling is permitted only once the
    // complete stream has left below the viewport.
    final initialHead = CommandCenterAmbientProcessing.initialEntryHeadFor(
      layer: layer,
      streamIndex: streamIndex,
    );
    final firstExitDistance = size.height + trail + glyphSize - initialHead;
    if (travel < firstExitDistance) {
      return _DataRainStreamPosition(
        head: initialHead + travel,
        recycleIndex: 0,
      );
    }
    final afterFirstExit = travel - firstExitDistance;
    return _DataRainStreamPosition(
      head: afterFirstExit % span - trail,
      recycleIndex: 1 + afterFirstExit ~/ span,
    );
  }

  /// A moving pulse follows glyph positions, independently of stream travel.
  /// It may begin in either direction and never draws detached light geometry.
  double _pulseStrength(int streamIndex, int glyphPosition, int length) {
    if (staticFrame()) return 0;
    final clustered = _hash(streamIndex, 131 + layer.index * 7) % 5 == 0;
    final pulseKey = clustered ? streamIndex ~/ 3 : streamIndex;
    final interval = 4.4 + (_hash(pulseKey, 137 + layer.index * 17) % 11) * .46;
    final duration =
        .72 + (_hash(streamIndex, 139 + layer.index * 23) % 7) * .15;
    final phase =
        (_hash(pulseKey, 149 + layer.index * 29) % 1000) / 1000 * interval;
    final local = (_seconds + phase) % interval;
    if (local > duration) return 0;
    final direction = CommandCenterAmbientProcessing.pulseDirectionForStream(
      layer: layer,
      streamIndex: streamIndex,
    );
    final pulseLength = 1.4 + (_hash(streamIndex, 151) % 4) * .48;
    final progress = local / duration;
    final position = direction == DataRainPulseDirection.downward
        ? -pulseLength + progress * (length - 1 + pulseLength * 2)
        : length - 1 + pulseLength - progress * (length - 1 + pulseLength * 2);
    final distance = (glyphPosition - position).abs();
    if (distance > pulseLength) return 0;
    return 1 - distance / pulseLength;
  }

  void _paintGlyph(
    Canvas canvas, {
    required Offset center,
    required double size,
    required String glyph,
    required Color color,
  }) {
    _glyphPaint.color = color;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(size);
    canvas.drawPath(_IndustrialGlyphAtlas.pathFor(glyph), _glyphPaint);
    canvas.restore();
  }

  void _paintMidRearSegment(
    Canvas canvas, {
    required Offset center,
    required Color color,
  }) {
    _segmentPaint
      ..color = color
      ..strokeWidth = CommandCenterAmbientProcessing.midRearSegmentStrokeWidth;
    final halfWidth = CommandCenterAmbientProcessing.midRearSegmentWidth / 2;
    canvas.drawLine(
      Offset(center.dx - halfWidth, center.dy),
      Offset(center.dx + halfWidth, center.dy),
      _segmentPaint,
    );
  }

  int _hash(int value, int salt) =>
      CommandCenterAmbientProcessing._hash(value, salt);

  @override
  bool shouldRepaint(covariant _IndustrialDataRainPainter oldDelegate) =>
      oldDelegate.layer != layer;
}

class _DataRainStreamPosition {
  const _DataRainStreamPosition({
    required this.head,
    required this.recycleIndex,
  });

  final double head;
  final int recycleIndex;
}

class _IndustrialGlyphAtlas {
  static const _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _numbers = '0123456789';
  static const _symbols = r'+-/\=:[]<>';

  static String glyphFor(int seed, int position) {
    final slot =
        (seed + position) % CommandCenterAmbientProcessing.glyphCategoryPeriod;
    final source = slot < CommandCenterAmbientProcessing.letterSlotsPerPeriod
        ? _letters
        : slot <
              CommandCenterAmbientProcessing.letterSlotsPerPeriod +
                  CommandCenterAmbientProcessing.numberSlotsPerPeriod
        ? _numbers
        : _symbols;
    final selection = CommandCenterAmbientProcessing._hash(
      seed + position * 37,
      163,
    );
    return source[selection % source.length];
  }

  /// 5×7 monospaced dot-matrix patterns: angular, technical and independent
  /// from device fonts. Each integer supplies one left-to-right five-bit row.
  static const _patterns = <String, List<int>>{
    'A': [14, 17, 17, 31, 17, 17, 17],
    'B': [30, 17, 17, 30, 17, 17, 30],
    'C': [15, 16, 16, 16, 16, 16, 15],
    'D': [30, 17, 17, 17, 17, 17, 30],
    'E': [31, 16, 16, 30, 16, 16, 31],
    'F': [31, 16, 16, 30, 16, 16, 16],
    'G': [15, 16, 16, 23, 17, 17, 15],
    'H': [17, 17, 17, 31, 17, 17, 17],
    'I': [31, 4, 4, 4, 4, 4, 31],
    'J': [7, 2, 2, 2, 18, 18, 12],
    'K': [17, 18, 20, 24, 20, 18, 17],
    'L': [16, 16, 16, 16, 16, 16, 31],
    'M': [17, 27, 21, 21, 17, 17, 17],
    'N': [17, 25, 21, 19, 17, 17, 17],
    'O': [14, 17, 17, 17, 17, 17, 14],
    'P': [30, 17, 17, 30, 16, 16, 16],
    'Q': [14, 17, 17, 17, 21, 18, 13],
    'R': [30, 17, 17, 30, 20, 18, 17],
    'S': [15, 16, 16, 14, 1, 1, 30],
    'T': [31, 4, 4, 4, 4, 4, 4],
    'U': [17, 17, 17, 17, 17, 17, 14],
    'V': [17, 17, 17, 17, 17, 10, 4],
    'W': [17, 17, 17, 21, 21, 27, 17],
    'X': [17, 17, 10, 4, 10, 17, 17],
    'Y': [17, 17, 10, 4, 4, 4, 4],
    'Z': [31, 1, 2, 4, 8, 16, 31],
    '0': [14, 17, 19, 21, 25, 17, 14],
    '1': [4, 12, 4, 4, 4, 4, 14],
    '2': [14, 17, 1, 2, 4, 8, 31],
    '3': [30, 1, 1, 14, 1, 1, 30],
    '4': [2, 6, 10, 18, 31, 2, 2],
    '5': [31, 16, 16, 30, 1, 1, 30],
    '6': [14, 16, 16, 30, 17, 17, 14],
    '7': [31, 1, 2, 4, 8, 8, 8],
    '8': [14, 17, 17, 14, 17, 17, 14],
    '9': [14, 17, 17, 15, 1, 1, 14],
    '+': [0, 4, 4, 31, 4, 4, 0],
    '-': [0, 0, 0, 31, 0, 0, 0],
    '/': [1, 2, 2, 4, 8, 8, 16],
    r'\': [16, 8, 8, 4, 2, 2, 1],
    '=': [0, 31, 0, 31, 0, 0, 0],
    ':': [0, 4, 4, 0, 4, 4, 0],
    '[': [14, 8, 8, 8, 8, 8, 14],
    ']': [14, 2, 2, 2, 2, 2, 14],
    '<': [2, 4, 8, 16, 8, 4, 2],
    '>': [8, 4, 2, 1, 2, 4, 8],
  };

  static List<int> rowsFor(String glyph) => _patterns[glyph]!;

  static final _fullPaths = <String, Path>{};

  static Path pathFor(String glyph) {
    return _fullPaths.putIfAbsent(glyph, () {
      final path = Path();
      final rows = rowsFor(glyph);
      const pixel = .15;
      for (var row = 0; row < rows.length; row++) {
        for (var column = 0; column < 5; column++) {
          if ((rows[row] & (1 << (4 - column))) == 0) continue;
          path.addRect(
            Rect.fromCenter(
              center: Offset(
                (column - 2) * pixel * 1.45,
                (row - 3) * pixel * 1.45,
              ),
              width: pixel,
              height: pixel,
            ),
          );
        }
      }
      return path;
    });
  }
}
