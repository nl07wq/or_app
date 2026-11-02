import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:or_app/core/widgets/global_touch_ripple.dart';

/// The registered image remains the single visual source. Facility regions are
/// normalised against it so the image, feedback affordances, and hit testing
/// always receive the same [InteractiveViewer] transform.
const baseCampMapAsset = 'assets/images/themes/base_camp/base_camp_map.png';
const baseCampWalkerUpLeftAsset =
    'assets/images/themes/base_camp/base_camp_walker_up_left.gif';
const baseCampWalkerDownRightAsset =
    'assets/images/themes/base_camp/base_camp_walker_down_right.gif';

/// Fully composited RGBA frames extracted directly from the approved GIFs.
/// They avoid Flutter Web's inconsistent GIF disposal/transparent-palette
/// composition while preserving every source pixel and the 140ms cadence.
const baseCampWalkerDownRightFrames = <String>[
  'assets/images/themes/base_camp/base_camp_walker_down_right/frame_00.png',
  'assets/images/themes/base_camp/base_camp_walker_down_right/frame_01.png',
  'assets/images/themes/base_camp/base_camp_walker_down_right/frame_02.png',
  'assets/images/themes/base_camp/base_camp_walker_down_right/frame_03.png',
  'assets/images/themes/base_camp/base_camp_walker_down_right/frame_04.png',
  'assets/images/themes/base_camp/base_camp_walker_down_right/frame_05.png',
  'assets/images/themes/base_camp/base_camp_walker_down_right/frame_06.png',
];

const baseCampWalkerUpLeftFrames = <String>[
  'assets/images/themes/base_camp/base_camp_walker_up_left/frame_00.png',
  'assets/images/themes/base_camp/base_camp_walker_up_left/frame_01.png',
  'assets/images/themes/base_camp/base_camp_walker_up_left/frame_02.png',
  'assets/images/themes/base_camp/base_camp_walker_up_left/frame_03.png',
  'assets/images/themes/base_camp/base_camp_walker_up_left/frame_04.png',
  'assets/images/themes/base_camp/base_camp_walker_up_left/frame_05.png',
  'assets/images/themes/base_camp/base_camp_walker_up_left/frame_06.png',
  'assets/images/themes/base_camp/base_camp_walker_up_left/frame_07.png',
];

List<String> baseCampWalkerFrameAssets(String gifAsset) => switch (gifAsset) {
  baseCampWalkerDownRightAsset => baseCampWalkerDownRightFrames,
  baseCampWalkerUpLeftAsset => baseCampWalkerUpLeftFrames,
  _ => throw ArgumentError.value(gifAsset, 'gifAsset', 'Unknown walker asset'),
};

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

/// The visual reference is 1672 x 940. These are the independently digitised
/// centre-lines in the registered 1280 x 719 map coordinate system:
///
/// * A (reference only): (247,348) ... (514,229)
/// * B: (882,275) ... (1112,404)
/// * C: (616,474) ... (808,604)
///
/// Route A intentionally remains a reference-only route. Neither approved
/// walker sprite faces its requested direction, so no unapproved rotation or
/// additional walker is introduced for it. The reverse legs use the supplied
/// up/left frames without transforming either approved asset.
const baseCampWalkerRoutes = <BaseCampWalkerRoute>[
  BaseCampWalkerRoute(
    id: 'route-b',
    sourcePoints: <Offset>[
      Offset(882, 275),
      Offset(914, 295),
      Offset(957, 317),
      Offset(998, 337),
      Offset(1040, 361),
      Offset(1080, 386),
      Offset(1112, 404),
    ],
    speed: BaseCampWalkingSettings.routeBSpeed,
    pausePatternSeconds: <double>[3.2, 2.5, 3.8, 2.3],
    initialPhaseSeconds: 1.8,
  ),
  BaseCampWalkerRoute(
    id: 'route-c',
    sourcePoints: <Offset>[
      Offset(616, 474),
      Offset(650, 497),
      Offset(695, 521),
      Offset(739, 546),
      Offset(781, 573),
      Offset(808, 604),
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
    this.outlinePoints,
  });

  final String id;
  final String label;
  final Offset center;
  final Size size;

  /// Normalised, irregular closed perimeter around the actual building.
  /// Hit testing intentionally continues to use [center]/[size], keeping the
  /// existing generous facility targets unchanged.
  final List<Offset>? outlinePoints;

  List<Offset> outline() {
    final customOutline = outlinePoints;
    if (customOutline != null) return customOutline;
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
    outlinePoints: <Offset>[
      Offset(.092, .350),
      Offset(.122, .294),
      Offset(.191, .265),
      Offset(.278, .271),
      Offset(.342, .310),
      Offset(.349, .374),
      Offset(.311, .432),
      Offset(.228, .449),
      Offset(.137, .429),
      Offset(.086, .391),
    ],
  ),
  BaseCampFacility(
    id: 'food',
    label: 'FOOD',
    center: Offset(.500, .270),
    size: Size(.25, .20),
    outlinePoints: <Offset>[
      Offset(.333, .278),
      Offset(.353, .208),
      Offset(.419, .164),
      Offset(.543, .154),
      Offset(.612, .192),
      Offset(.624, .268),
      Offset(.590, .339),
      Offset(.505, .363),
      Offset(.402, .346),
      Offset(.344, .318),
    ],
  ),
  BaseCampFacility(
    id: 'training',
    label: 'TRAINING',
    center: Offset(.785, .345),
    size: Size(.24, .24),
    outlinePoints: <Offset>[
      Offset(.649, .327),
      Offset(.684, .255),
      Offset(.754, .211),
      Offset(.865, .223),
      Offset(.911, .281),
      Offset(.904, .362),
      Offset(.861, .436),
      Offset(.765, .453),
      Offset(.687, .421),
      Offset(.651, .375),
    ],
  ),
  BaseCampFacility(
    id: 'activity',
    label: 'ACTIVITY',
    center: Offset(.285, .630),
    size: Size(.25, .22),
    outlinePoints: <Offset>[
      Offset(.115, .642),
      Offset(.144, .574),
      Offset(.218, .526),
      Offset(.340, .519),
      Offset(.410, .563),
      Offset(.426, .636),
      Offset(.392, .705),
      Offset(.307, .731),
      Offset(.194, .712),
      Offset(.132, .680),
    ],
  ),
  BaseCampFacility(
    id: 'command-center',
    label: 'COMMAND CENTER',
    center: Offset(.705, .640),
    size: Size(.28, .25),
    outlinePoints: <Offset>[
      Offset(.486, .632),
      Offset(.527, .563),
      Offset(.610, .522),
      Offset(.751, .526),
      Offset(.843, .580),
      Offset(.854, .657),
      Offset(.817, .734),
      Offset(.727, .769),
      Offset(.607, .757),
      Offset(.523, .708),
      Offset(.482, .665),
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
                key: const ValueKey('base-camp-map'),
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
                                key: const ValueKey('base-camp-walkers'),
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
                                    'base-camp-selection-frame',
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
                    key: const ValueKey('base-camp-reset'),
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
      key: ValueKey('base-camp-facility-${facility.id}'),
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
                  key: const ValueKey('base-camp-confirm-no'),
                  label: 'NO',
                  onPressed: enabled ? onNo : null,
                ),
                const SizedBox(width: 6),
                _ConfirmationButton(
                  key: const ValueKey('base-camp-confirm-yes'),
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
    final points = facility
        .outline()
        .map((point) => Offset(point.dx * size.width, point.dy * size.height))
        .toList(growable: false);
    final path = Path()..addPolygon(points, true);
    // The reference calls for a hand-drawn perimeter around the facility, not
    // a generic cyan HUD rectangle. A restrained alpha pulse keeps selection
    // legible without changing the outline's white material.
    final intensity = .78 + .22 * ((1 + math.sin(pulse * math.pi * 2)) / 2);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: .16 * intensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: .76 + .20 * intensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // A thin displaced pass gives the outline its slightly organic, traced
    // character while remaining tied to the same transformed facility path.
    canvas.drawPath(
      path.shift(const Offset(.55, -.35)),
      Paint()
        ..color = Colors.white.withValues(alpha: .22 * intensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .65,
    );
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
      key: ValueKey('base-camp-walker-${route.id}'),
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

class _BaseCampGifWalkerState extends State<_BaseCampGifWalker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _frames;

  Duration get _cycleDuration => Duration(
    milliseconds: baseCampWalkerFrameAssets(widget.assetPath).length * 140,
  );

  @override
  void initState() {
    super.initState();
    _frames = AnimationController(vsync: this, duration: _cycleDuration);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(_BaseCampGifWalker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _frames
        ..duration = _cycleDuration
        ..value = 0;
    }
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.walking && !widget.reducedMotion) {
      if (!_frames.isAnimating) _frames.repeat();
    } else {
      _frames
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _frames.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = baseCampWalkerFrameAssets(widget.assetPath);
    return AnimatedBuilder(
      animation: _frames,
      builder: (_, _) {
        final index = widget.walking && !widget.reducedMotion
            ? (_frames.value * frames.length).floor() % frames.length
            : 0;
        return Image.asset(
          frames[index],
          key: ValueKey('${widget.assetPath}:$index'),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
          gaplessPlayback: true,
        );
      },
    );
  }
}
