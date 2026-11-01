import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:or_app/core/widgets/global_touch_ripple.dart';

/// The registered image remains the single visual source. Facility regions are
/// normalised against it so the image, feedback affordances, and hit testing
/// always receive the same [InteractiveViewer] transform.
const baseCampMapAsset = 'assets/images/themes/new/base_camp_map.png';
const baseCampWalkerUpLeftAsset =
    'assets/images/themes/new/base_camp_walker_up_left.gif';
const baseCampWalkerDownRightAsset =
    'assets/images/themes/new/base_camp_walker_down_right.gif';

/// The source dimensions of both the approved map and the white-line route
/// reference. Keeping route points in this coordinate system makes their
/// alignment independent of the dashboard's displayed size and map zoom.
const baseCampMapSourceSize = Size(1280, 719);

/// Tunable walking presentation values in map-source pixels/seconds.
abstract final class BaseCampWalkingSettings {
  static const spriteHeight = 66.0;
  static const routeBSpeed = 54.0;
  static const routeCSpeed = 50.0;
}

@immutable
class BaseCampWalkerRoute {
  const BaseCampWalkerRoute({
    required this.id,
    required this.sourcePoints,
    required this.speed,
    required this.pausePatternSeconds,
    this.initialPhaseSeconds = 0,
  });

  final String id;

  /// Centre-line coordinates digitised from the supplied 1280 x 719 route
  /// reference image. Route A is intentionally absent: its direction does
  /// not match either approved GIF direction.
  final List<Offset> sourcePoints;
  final double speed;

  /// Deterministic 2–4 second endpoint dwell times. Cycling the pattern keeps
  /// the routes replayable while avoiding a visually mechanical fixed pause.
  final List<double> pausePatternSeconds;
  final double initialPhaseSeconds;

  List<Offset> get normalizedPoints => sourcePoints
      .map(
        (point) => Offset(
          point.dx / baseCampMapSourceSize.width,
          point.dy / baseCampMapSourceSize.height,
        ),
      )
      .toList(growable: false);
}

/// The two approved walker routes, digitised from the white-line map.
///
/// Route B: (770,275) -> (1128,416), forward direction is right/down.
/// Route C: (533,503) -> (785,611), forward direction is right/down.
/// The reverse leg uses the separately supplied up/left GIF without rotating
/// or transforming either asset.
const baseCampWalkerRoutes = <BaseCampWalkerRoute>[
  BaseCampWalkerRoute(
    id: 'route-b',
    sourcePoints: <Offset>[
      Offset(770, 275),
      Offset(806, 292),
      Offset(850, 309),
      Offset(899, 319),
      Offset(945, 330),
      Offset(989, 350),
      Offset(1030, 375),
      Offset(1070, 399),
      Offset(1128, 416),
    ],
    speed: BaseCampWalkingSettings.routeBSpeed,
    pausePatternSeconds: <double>[3.2, 2.5, 3.8, 2.3],
    initialPhaseSeconds: 1.8,
  ),
  BaseCampWalkerRoute(
    id: 'route-c',
    sourcePoints: <Offset>[
      Offset(533, 503),
      Offset(566, 520),
      Offset(606, 537),
      Offset(649, 553),
      Offset(691, 568),
      Offset(730, 588),
      Offset(758, 603),
      Offset(785, 611),
    ],
    speed: BaseCampWalkingSettings.routeCSpeed,
    pausePatternSeconds: <double>[3.7, 2.8, 2.4, 3.3],
    initialPhaseSeconds: 7.1,
  ),
];

@immutable
class BaseCampFacility {
  const BaseCampFacility({
    required this.id,
    required this.label,
    required this.center,
    required this.size,
    this.frameCorners,
  });

  final String id;
  final String label;
  final Offset center;
  final Size size;

  /// Normalised, clockwise corners for the 2.5D selection frame.  Hit
  /// testing intentionally continues to use [center]/[size], keeping the
  /// existing generous facility targets unchanged.
  final List<Offset>? frameCorners;

  List<Offset> corners() {
    final customCorners = frameCorners;
    if (customCorners != null) return customCorners;
    final halfWidth = size.width / 2;
    final halfHeight = size.height / 2;
    return <Offset>[
      Offset(center.dx - halfWidth, center.dy - halfHeight),
      Offset(center.dx + halfWidth, center.dy - halfHeight),
      Offset(center.dx + halfWidth, center.dy + halfHeight),
      Offset(center.dx - halfWidth, center.dy + halfHeight),
    ];
  }
}

const baseCampFacilities = <BaseCampFacility>[
  BaseCampFacility(
    id: 'status',
    label: 'STATUS',
    center: Offset(.235, .355),
    size: Size(.24, .22),
    frameCorners: <Offset>[
      Offset(.125, .275),
      Offset(.345, .288),
      Offset(.335, .432),
      Offset(.12, .418),
    ],
  ),
  BaseCampFacility(
    id: 'food',
    label: 'FOOD',
    center: Offset(.500, .270),
    size: Size(.25, .20),
    frameCorners: <Offset>[
      Offset(.38, .195),
      Offset(.62, .204),
      Offset(.61, .335),
      Offset(.385, .325),
    ],
  ),
  BaseCampFacility(
    id: 'training',
    label: 'TRAINING',
    center: Offset(.785, .345),
    size: Size(.24, .24),
    frameCorners: <Offset>[
      Offset(.67, .255),
      Offset(.90, .275),
      Offset(.89, .43),
      Offset(.675, .413),
    ],
  ),
  BaseCampFacility(
    id: 'activity',
    label: 'ACTIVITY',
    center: Offset(.285, .630),
    size: Size(.25, .22),
    frameCorners: <Offset>[
      Offset(.17, .55),
      Offset(.41, .565),
      Offset(.40, .71),
      Offset(.175, .70),
    ],
  ),
  BaseCampFacility(
    id: 'command-center',
    label: 'COMMAND CENTER',
    center: Offset(.705, .640),
    size: Size(.28, .25),
    frameCorners: <Offset>[
      Offset(.57, .54),
      Offset(.84, .56),
      Offset(.83, .715),
      Offset(.575, .70),
    ],
  ),
];

class BaseCampMap extends StatefulWidget {
  const BaseCampMap({super.key, required this.onFacilityPressed});

  final ValueChanged<BaseCampFacility> onFacilityPressed;

  @override
  State<BaseCampMap> createState() => _BaseCampMapState();
}

class _BaseCampMapState extends State<BaseCampMap>
    with TickerProviderStateMixin {
  static const _interactionReleaseDelay = Duration(milliseconds: 140);
  final TransformationController _transform = TransformationController();
  Timer? _interactionRelease;
  bool _isTransforming = false;
  bool _isNavigating = false;
  BaseCampFacility? _selectedFacility;
  late final AnimationController _selectionPulse;
  late final AnimationController _walkerTimeline;

  @override
  void initState() {
    super.initState();
    _selectionPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _walkerTimeline = AnimationController(
      vsync: this,
      // The sampler is time based. A long controller avoids a visible reset
      // while keeping its ticker scoped to the dashboard's TickerMode.
      duration: const Duration(hours: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _interactionRelease?.cancel();
    _selectionPulse.dispose();
    _walkerTimeline.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _beginInteraction(ScaleStartDetails _) {
    _interactionRelease?.cancel();
    _isTransforming = true;
  }

  void _endInteraction(ScaleEndDetails _) {
    _interactionRelease?.cancel();
    _interactionRelease = Timer(_interactionReleaseDelay, () {
      if (mounted) setState(() => _isTransforming = false);
    });
  }

  void _reset() {
    _interactionRelease?.cancel();
    setState(() {
      _isTransforming = false;
      _transform.value = Matrix4.identity();
    });
  }

  void _openFacility(BaseCampFacility facility) {
    if (_isTransforming) return;
    setState(() => _selectedFacility = facility);
  }

  void _clearSelection() {
    if (_isNavigating) return;
    setState(() => _selectedFacility = null);
  }

  void _confirmSelection() {
    final facility = _selectedFacility;
    if (facility == null || _isNavigating) return;
    setState(() => _isNavigating = true);
    widget.onFacilityPressed(facility);
    if (mounted) {
      setState(() {
        _selectedFacility = null;
        _isNavigating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final selectedFacility = _selectedFacility;
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                key: const ValueKey('new-theme-base-camp-map'),
                transformationController: _transform,
                minScale: 1,
                maxScale: 2.4,
                boundaryMargin: EdgeInsets.zero,
                constrained: true,
                panEnabled: true,
                scaleEnabled: true,
                onInteractionStart: _beginInteraction,
                onInteractionEnd: _endInteraction,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.biggest;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        const Image(
                          image: AssetImage(baseCampMapAsset),
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                        ),
                        IgnorePointer(
                          child: RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _walkerTimeline,
                              builder: (context, _) => _BaseCampWalkerLayer(
                                key: const ValueKey(
                                  'new-theme-base-camp-walkers',
                                ),
                                elapsed: reducedMotion
                                    ? Duration.zero
                                    : Duration(
                                        microseconds:
                                            (_walkerTimeline.value *
                                                    Duration.microsecondsPerDay)
                                                .round(),
                                      ),
                                reducedMotion: reducedMotion,
                              ),
                            ),
                          ),
                        ),
                        if (selectedFacility != null)
                          IgnorePointer(
                            child: RepaintBoundary(
                              child: AnimatedBuilder(
                                animation: _selectionPulse,
                                builder: (context, _) => CustomPaint(
                                  key: const ValueKey(
                                    'new-theme-base-camp-selection-frame',
                                  ),
                                  painter: _FacilitySelectionFramePainter(
                                    facility: selectedFacility,
                                    pulse: reducedMotion
                                        ? 0
                                        : _selectionPulse.value,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                        for (final facility in baseCampFacilities)
                          _BaseCampFacilityTarget(
                            facility: facility,
                            mapSize: size,
                            onPressed: () => _openFacility(facility),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Tooltip(
                  message: 'Reset map framing',
                  child: IconButton.filledTonal(
                    key: const ValueKey('new-theme-base-camp-reset'),
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh),
                  ).actionableFeedback(role: ActionableFeedbackRole.cursor),
                ),
              ),
              if (selectedFacility != null)
                _FacilityConfirmation(
                  facility: selectedFacility,
                  onNo: _clearSelection,
                  onYes: _confirmSelection,
                  enabled: !_isNavigating,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BaseCampFacilityTarget extends StatelessWidget {
  const _BaseCampFacilityTarget({
    required this.facility,
    required this.mapSize,
    required this.onPressed,
  });

  final BaseCampFacility facility;
  final Size mapSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final width = mapSize.width * facility.size.width;
    final height = mapSize.height * facility.size.height;
    return Positioned(
      key: ValueKey('new-theme-base-camp-facility-${facility.id}'),
      left: mapSize.width * facility.center.dx - width / 2,
      top: mapSize.height * facility.center.dy - height / 2,
      width: width,
      height: height,
      child: Semantics(
        button: true,
        label: '${facility.label} facility',
        child: ActionableFeedbackRegion(
          role: ActionableFeedbackRole.command,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _FacilityConfirmation extends StatelessWidget {
  const _FacilityConfirmation({
    required this.facility,
    required this.onNo,
    required this.onYes,
    required this.enabled,
  });

  final BaseCampFacility facility;
  final VoidCallback onNo;
  final VoidCallback onYes;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 12,
    right: 12,
    bottom: 10,
    child: SafeArea(
      top: false,
      child: Semantics(
        container: true,
        label: 'Facility navigation confirmation',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE9142026),
            border: Border.all(
              color: const Color(0xFF68E8F2).withValues(alpha: .65),
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x5540C9DC),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: const Color(0xFFDDFBFF),
                      height: 1.25,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('BASE CAMP / FACILITY SELECT'),
                        const SizedBox(height: 2),
                        Text(
                          facility.label,
                          style: Theme.of(context).textTheme.titleSmall!
                              .copyWith(
                                color: const Color(0xFF68E8F2),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const Text('この施設へ移動しますか？'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ConfirmationButton(
                  key: const ValueKey('new-theme-base-camp-confirm-no'),
                  label: 'NO',
                  onPressed: enabled ? onNo : null,
                ),
                const SizedBox(width: 6),
                _ConfirmationButton(
                  key: const ValueKey('new-theme-base-camp-confirm-yes'),
                  label: 'YES',
                  highlighted: true,
                  onPressed: enabled ? onYes : null,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ConfirmationButton extends StatelessWidget {
  const _ConfirmationButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.highlighted = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    height: 44,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: highlighted
            ? const Color(0xFF03161A)
            : const Color(0xFFB9F7FF),
        backgroundColor: highlighted
            ? const Color(0xFF68E8F2)
            : const Color(0x182E9DAC),
        side: const BorderSide(color: Color(0xFF68E8F2)),
        padding: EdgeInsets.zero,
        textStyle: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    ).actionableFeedback(role: ActionableFeedbackRole.cursor),
  );
}

class _FacilitySelectionFramePainter extends CustomPainter {
  const _FacilitySelectionFramePainter({
    required this.facility,
    required this.pulse,
  });

  final BaseCampFacility facility;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final corners = facility
        .corners()
        .map(
          (corner) => Offset(corner.dx * size.width, corner.dy * size.height),
        )
        .toList(growable: false);
    final path = Path()..addPolygon(corners, true);
    final intensity = .55 + .45 * ((1 + math.sin(pulse * math.pi * 2)) / 2);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF68E8F2).withValues(alpha: .18 * intensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(
          0xFF68E8F2,
        ).withValues(alpha: .75 + .25 * intensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final cornerAccent = Paint()
      ..color = const Color(0xFFE0FCFF)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.square;
    for (var index = 0; index < corners.length; index++) {
      final current = corners[index];
      final next = corners[(index + 1) % corners.length];
      final previous = corners[(index - 1 + corners.length) % corners.length];
      canvas.drawLine(current, Offset.lerp(current, next, .13)!, cornerAccent);
      canvas.drawLine(
        current,
        Offset.lerp(current, previous, .13)!,
        cornerAccent,
      );
    }
  }

  @override
  bool shouldRepaint(_FacilitySelectionFramePainter oldDelegate) =>
      oldDelegate.facility != facility || oldDelegate.pulse != pulse;
}

@immutable
class BaseCampWalkerPose {
  const BaseCampWalkerPose({
    required this.sourcePosition,
    required this.direction,
    required this.isWalking,
  });

  final Offset sourcePosition;
  final Offset direction;
  final bool isWalking;

  bool get usesDownRightAsset => direction.dx >= 0 && direction.dy >= 0;
}

/// Time-based route sampler. It is independent of render frame rate and keeps
/// a walker exactly on its digitised source-image polyline in either direction.
BaseCampWalkerPose baseCampWalkerPose(String id, Duration elapsed) {
  final route = baseCampWalkerRoutes.singleWhere((route) => route.id == id);
  final metrics = _BaseCampRouteMetrics(route);
  final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  final local = (seconds + route.initialPhaseSeconds) % metrics.cycleSeconds;
  return metrics.poseAtElapsed(local);
}

/// Exposed for deterministic route-cycle verification without inspecting a
/// rendered frame. The duration includes the deterministic randomised pattern
/// of endpoint waits.
Duration baseCampWalkerCycleDuration(String id) {
  final route = baseCampWalkerRoutes.singleWhere((route) => route.id == id);
  return Duration(
    microseconds:
        (_BaseCampRouteMetrics(route).cycleSeconds *
                Duration.microsecondsPerSecond)
            .round(),
  );
}

class _BaseCampRouteMetrics {
  _BaseCampRouteMetrics(this.route)
    : segments = List<_BaseCampRouteSegment>.generate(
        route.sourcePoints.length - 1,
        (index) => _BaseCampRouteSegment(
          route.sourcePoints[index],
          route.sourcePoints[index + 1],
        ),
      ) {
    length = segments.fold<double>(0, (sum, segment) => sum + segment.length);
  }

  final BaseCampWalkerRoute route;
  final List<_BaseCampRouteSegment> segments;
  late final double length;

  double get travelSeconds => length / route.speed;
  double get cycleSeconds =>
      travelSeconds * route.pausePatternSeconds.length +
      route.pausePatternSeconds.fold<double>(0, (sum, pause) => sum + pause);

  double distanceAtTime(double seconds) => (seconds / travelSeconds) * length;

  BaseCampWalkerPose poseAtElapsed(double elapsedSeconds) {
    var remaining = elapsedSeconds;
    for (var leg = 0; leg < route.pausePatternSeconds.length; leg++) {
      final forward = leg.isEven;
      if (remaining < travelSeconds) {
        final distance = distanceAtTime(remaining);
        return poseAtDistance(
          forward ? distance : length - distance,
          isWalking: true,
          forward: forward,
        );
      }
      remaining -= travelSeconds;
      if (remaining < route.pausePatternSeconds[leg]) {
        return poseAtDistance(
          forward ? length : 0,
          isWalking: false,
          forward: forward,
        );
      }
      remaining -= route.pausePatternSeconds[leg];
    }
    return poseAtDistance(0, isWalking: false, forward: false);
  }

  BaseCampWalkerPose poseAtDistance(
    double distance, {
    required bool isWalking,
    required bool forward,
  }) {
    var remaining = distance.clamp(0, length).toDouble();
    for (final segment in segments) {
      if (remaining <= segment.length) {
        return BaseCampWalkerPose(
          sourcePosition: Offset.lerp(
            segment.start,
            segment.end,
            segment.length == 0 ? 0 : remaining / segment.length,
          )!,
          direction: forward ? segment.delta : -segment.delta,
          isWalking: isWalking,
        );
      }
      remaining -= segment.length;
    }
    final segment = segments.last;
    return BaseCampWalkerPose(
      sourcePosition: segment.end,
      direction: forward ? segment.delta : -segment.delta,
      isWalking: isWalking,
    );
  }
}

class _BaseCampRouteSegment {
  const _BaseCampRouteSegment(this.start, this.end);

  final Offset start;
  final Offset end;

  Offset get delta => end - start;
  double get length => delta.distance;
}

class _BaseCampWalkerLayer extends StatelessWidget {
  const _BaseCampWalkerLayer({
    super.key,
    required this.elapsed,
    required this.reducedMotion,
  });

  final Duration elapsed;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapSize = constraints.biggest;
        final spriteHeight =
            mapSize.width /
            baseCampMapSourceSize.width *
            BaseCampWalkingSettings.spriteHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            for (final route in baseCampWalkerRoutes)
              _BaseCampGifWalkerPositioned(
                route: route,
                pose: baseCampWalkerPose(route.id, elapsed),
                mapSize: mapSize,
                spriteHeight: spriteHeight,
                reducedMotion: reducedMotion,
              ),
          ],
        );
      },
    );
  }
}

class _BaseCampGifWalkerPositioned extends StatelessWidget {
  const _BaseCampGifWalkerPositioned({
    required this.route,
    required this.pose,
    required this.mapSize,
    required this.spriteHeight,
    required this.reducedMotion,
  });

  final BaseCampWalkerRoute route;
  final BaseCampWalkerPose pose;
  final Size mapSize;
  final double spriteHeight;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final width = spriteHeight * .6;
    final position = Offset(
      pose.sourcePosition.dx / baseCampMapSourceSize.width * mapSize.width,
      pose.sourcePosition.dy / baseCampMapSourceSize.height * mapSize.height,
    );
    return Positioned(
      key: ValueKey('new-theme-base-camp-walker-${route.id}'),
      left: position.dx - width / 2,
      top: position.dy - spriteHeight,
      width: width,
      height: spriteHeight,
      child: _BaseCampGifWalker(
        assetPath: pose.usesDownRightAsset
            ? baseCampWalkerDownRightAsset
            : baseCampWalkerUpLeftAsset,
        walking: pose.isWalking,
        reducedMotion: reducedMotion,
      ),
    );
  }
}

/// Uses the approved animated asset while travelling, and its decoded first
/// GIF frame at route endpoints so a stopped walker does not keep stepping.
class _BaseCampGifWalker extends StatefulWidget {
  const _BaseCampGifWalker({
    required this.assetPath,
    required this.walking,
    required this.reducedMotion,
  });

  final String assetPath;
  final bool walking;
  final bool reducedMotion;

  @override
  State<_BaseCampGifWalker> createState() => _BaseCampGifWalkerState();
}

class _BaseCampGifWalkerState extends State<_BaseCampGifWalker> {
  ui.Image? _firstFrame;
  String? _loadedAsset;

  @override
  void initState() {
    super.initState();
    _loadFirstFrame();
  }

  @override
  void didUpdateWidget(_BaseCampGifWalker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) _loadFirstFrame();
  }

  Future<void> _loadFirstFrame() async {
    final assetPath = widget.assetPath;
    final bytes = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (!mounted || assetPath != widget.assetPath) return;
    setState(() {
      _firstFrame = frame.image;
      _loadedAsset = assetPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showAnimation = widget.walking && !widget.reducedMotion;
    if (!showAnimation &&
        _loadedAsset == widget.assetPath &&
        _firstFrame != null) {
      return RawImage(image: _firstFrame, fit: BoxFit.contain);
    }
    return Image.asset(
      widget.assetPath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      gaplessPlayback: true,
    );
  }
}
