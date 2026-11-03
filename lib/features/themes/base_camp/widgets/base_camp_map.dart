import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:or_app/core/widgets/global_touch_ripple.dart';
import 'package:or_app/features/themes/base_camp/base_camp_asset_store.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_configuration.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_editor_page.dart';

/// The registered image remains the single visual source. Facility regions are
/// normalised against it so the image, feedback affordances, and hit testing
/// always receive the same [InteractiveViewer] transform.
const baseCampMapAsset = 'assets/images/themes/base_camp/base_camp_map_v2.jpg';
const baseCampWalkerUpLeftAsset =
    'assets/images/themes/base_camp/base_camp_walker_up_left.gif';
const baseCampWalkerDownRightAsset =
    'assets/images/themes/base_camp/base_camp_walker_down_right.gif';

const baseCampObjectAssets = <String, String>{
  'status':
      'assets/images/themes/base_camp/objects/status_parabola_transparent_fixed.gif',
  'food': 'assets/images/themes/base_camp/objects/food.png',
  'training': 'assets/images/themes/base_camp/objects/training.gif',
  'activity': 'assets/images/themes/base_camp/objects/activity.gif',
  'command-center': 'assets/images/themes/base_camp/objects/command_center.png',
  'flag': 'assets/images/themes/base_camp/objects/flag.gif',
};

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
const baseCampMapSourceSize = Size(1280, 720);

/// Maps durable 1280×719 source coordinates to the actual painted image
/// rectangle. Both the normal dashboard (cover) and editor (contain) use the
/// same conversion so walker feet, route points and facility paths cannot
/// drift when a viewport crops, pans or changes aspect ratio.
@immutable
class BaseCampMapGeometry {
  const BaseCampMapGeometry._({
    required this.viewport,
    required this.imageRect,
  });

  factory BaseCampMapGeometry.cover(Size viewport) => BaseCampMapGeometry._(
    viewport: viewport,
    imageRect: _fittedRect(viewport, BoxFit.cover),
  );

  factory BaseCampMapGeometry.contain(Size viewport) => BaseCampMapGeometry._(
    viewport: viewport,
    imageRect: _fittedRect(viewport, BoxFit.contain),
  );

  final Size viewport;
  final Rect imageRect;

  double get scale => imageRect.width / baseCampMapSourceSize.width;

  Offset sourceToViewport(Offset point) => Offset(
    imageRect.left + point.dx * scale,
    imageRect.top + point.dy * scale,
  );

  Offset viewportToSource(Offset point) => Offset(
    (point.dx - imageRect.left) / scale,
    (point.dy - imageRect.top) / scale,
  );

  Offset normalizedToViewport(Offset point) => sourceToViewport(
    Offset(
      point.dx * baseCampMapSourceSize.width,
      point.dy * baseCampMapSourceSize.height,
    ),
  );

  static Rect _fittedRect(Size viewport, BoxFit fit) {
    final fitted = applyBoxFit(fit, baseCampMapSourceSize, viewport);
    final size = fitted.destination;
    return Alignment.center.inscribe(size, Offset.zero & viewport);
  }
}

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

  BaseCampWalkerRoute withSourcePoints(List<Offset> points) =>
      BaseCampWalkerRoute(
        id: id,
        sourcePoints: points,
        speed: speed,
        pausePatternSeconds: pausePatternSeconds,
        initialPhaseSeconds: initialPhaseSeconds,
      );

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
  /// It is the hit mask for opaque facility JPEGs, so a transparent or white
  /// pixel outside this contour never becomes a rectangular tap target.
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

/// Applies a facility object's edit transform to its irregular source-map
/// perimeter. The transformed path is shared by selection glow and hit tests.
List<Offset> baseCampFacilityOutlineForConfiguration(
  BaseCampFacility facility,
  BaseCampMapConfiguration configuration,
) {
  final fallback = baseCampDefaultObjects.singleWhere(
    (object) => object.id == facility.id,
  );
  final object = configuration.objects[facility.id] ?? fallback;
  final center = fallback.position;
  final cosine = math.cos(object.rotation);
  final sine = math.sin(object.rotation);
  return (configuration.facilityOutlines[facility.id] ?? facility.outline())
      .map((normalized) {
        final source = Offset(
          normalized.dx * baseCampMapSourceSize.width,
          normalized.dy * baseCampMapSourceSize.height,
        );
        final relative = (source - center) * object.scale;
        final rotated = Offset(
          relative.dx * cosine - relative.dy * sine,
          relative.dx * sine + relative.dy * cosine,
        );
        final transformed = object.position + rotated;
        return Offset(
          transformed.dx / baseCampMapSourceSize.width,
          transformed.dy / baseCampMapSourceSize.height,
        );
      })
      .toList(growable: false);
}

/// Returns whether a normalised source-map position is inside the curated
/// facility contour. This is the alpha-equivalent hit mask for the supplied
/// opaque JPEG facilities: their white/checkerboard pixels are image content,
/// not transparency, so the real building footprint is intentionally defined
/// by this path rather than by the image rectangle.
bool baseCampFacilityOutlineContains(
  List<Offset> normalizedOutline,
  Offset normalizedPosition,
) => (Path()..addPolygon(normalizedOutline, true)).contains(normalizedPosition);

class BaseCampMap extends StatefulWidget {
  const BaseCampMap({super.key, required this.onFacilityPressed});

  final ValueChanged<BaseCampFacility> onFacilityPressed;

  @override
  State<BaseCampMap> createState() => _BaseCampMapState();
}

class _BaseCampMapState extends State<BaseCampMap>
    with TickerProviderStateMixin {
  final TransformationController _transform = TransformationController();
  bool _isNavigating = false;
  BaseCampFacility? _selectedFacility;
  BaseCampFacility? _glowingFacility;
  late final AnimationController _selectionPulse;
  late final AnimationController _selectionVisibility;
  late final AnimationController _walkerTimeline;

  @override
  void initState() {
    super.initState();
    _selectionPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _selectionVisibility =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 150),
          reverseDuration: const Duration(milliseconds: 250),
        )..addStatusListener((status) {
          if (status == AnimationStatus.dismissed && mounted) {
            setState(() => _glowingFacility = null);
          }
        });
    _walkerTimeline = AnimationController(
      vsync: this,
      // The sampler is time based. A long controller avoids a visible reset
      // while keeping its ticker scoped to the dashboard's TickerMode.
      duration: const Duration(hours: 24),
    )..repeat();
    baseCampMapConfigurationController.load();
    baseCampMapConfigurationController.addListener(_configurationChanged);
  }

  void _configurationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _selectionPulse.dispose();
    _selectionVisibility.dispose();
    _walkerTimeline.dispose();
    baseCampMapConfigurationController.removeListener(_configurationChanged);
    _transform.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() => _transform.value = Matrix4.identity());
  }

  Future<void> _openEditor() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const BaseCampMapEditorPage()),
    );
  }

  void _openFacility(BaseCampFacility facility) {
    setState(() {
      _selectedFacility = facility;
      _glowingFacility = facility;
    });
    _selectionVisibility.forward(from: 0);
  }

  void _clearSelection() {
    if (_isNavigating) return;
    setState(() => _selectedFacility = null);
    _selectionVisibility.reverse();
  }

  void _confirmSelection() {
    final facility = _selectedFacility;
    if (facility == null || _isNavigating) return;
    setState(() => _isNavigating = true);
    widget.onFacilityPressed(facility);
    if (mounted) {
      setState(() {
        _selectedFacility = null;
        _glowingFacility = null;
        _selectionVisibility.value = 0;
        _isNavigating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final selectedFacility = _selectedFacility;
    final glowingFacility = _glowingFacility;
    final configuration = baseCampMapConfigurationController.value;
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.biggest;
                    final geometry = BaseCampMapGeometry.cover(size);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        const Image(
                          image: AssetImage(baseCampMapAsset),
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                        ),
                        IgnorePointer(
                          child: AnimatedBuilder(
                            animation: Listenable.merge(<Listenable>[
                              _selectionPulse,
                              _selectionVisibility,
                            ]),
                            builder: (context, _) {
                              final pulse = reducedMotion
                                  ? 1.0
                                  : .84 +
                                        .16 *
                                            ((1 +
                                                    math.sin(
                                                      _selectionPulse.value *
                                                          math.pi *
                                                          2,
                                                    )) /
                                                2);
                              return BaseCampObjectLayer(
                                configuration: configuration,
                                geometry: geometry,
                                highlightedObjectId: glowingFacility?.id,
                                highlightOpacity:
                                    _selectionVisibility.value * pulse,
                              );
                            },
                          ),
                        ),
                        IgnorePointer(
                          child: RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _walkerTimeline,
                              builder: (context, _) =>
                                  BaseCampWalkerPreviewLayer(
                                    key: const ValueKey('base-camp-walkers'),
                                    elapsed: reducedMotion
                                        ? Duration.zero
                                        : Duration(
                                            microseconds:
                                                (_walkerTimeline.value *
                                                        Duration
                                                            .microsecondsPerDay)
                                                    .round(),
                                          ),
                                    reducedMotion: reducedMotion,
                                    configuration: configuration,
                                    geometry: geometry,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // InteractiveViewer owns pan/pinch gestures.  Place alpha hit
              // surfaces above it and mirror its matrix so facility taps stay
              // aligned without competing with its full-screen recognizer.
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final geometry = BaseCampMapGeometry.cover(
                      constraints.biggest,
                    );
                    return Transform(
                      alignment: Alignment.topLeft,
                      transform: _transform.value,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          for (final facility in baseCampFacilities)
                            if (configuration.objects[facility.id]
                                case final object?)
                              _BaseCampAlphaFacilityTarget(
                                facility: facility,
                                object: object,
                                geometry: geometry,
                                onPressed: () => _openFacility(facility),
                              ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Tooltip(
                  message: 'Reset map framing',
                  child: GestureDetector(
                    onLongPress: _openEditor,
                    child: IconButton.filledTonal(
                      key: const ValueKey('base-camp-reset'),
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh),
                    ).actionableFeedback(role: ActionableFeedbackRole.cursor),
                  ),
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
  return baseCampWalkerPoseForRoute(route, elapsed);
}

BaseCampWalkerPose baseCampWalkerPoseForRoute(
  BaseCampWalkerRoute route,
  Duration elapsed,
) {
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

/// Renders facility art in the same source space as the map. The object
/// records contain only asset references; imported binary records remain out
/// of exported JSON and can be resolved by the persistence layer.
class BaseCampObjectLayer extends StatelessWidget {
  const BaseCampObjectLayer({
    super.key,
    required this.configuration,
    required this.geometry,
    this.highlightedObjectId,
    this.highlightOpacity = 0,
  });

  final BaseCampMapConfiguration configuration;
  final BaseCampMapGeometry geometry;
  final String? highlightedObjectId;
  final double highlightOpacity;

  @override
  Widget build(BuildContext context) {
    final objects =
        configuration.objects.values.where((item) => item.visible).toList()
          ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final object in objects)
          _BaseCampMapObjectPositioned(
            object: object,
            geometry: geometry,
            highlightOpacity: object.id == highlightedObjectId
                ? highlightOpacity
                : 0,
          ),
      ],
    );
  }
}

class _BaseCampMapObjectPositioned extends StatelessWidget {
  const _BaseCampMapObjectPositioned({
    required this.object,
    required this.geometry,
    this.highlightOpacity = 0,
  });
  final BaseCampMapObject object;
  final BaseCampMapGeometry geometry;
  final double highlightOpacity;

  @override
  Widget build(BuildContext context) {
    final asset = baseCampObjectAssets[object.assetId];
    final position = geometry.sourceToViewport(object.position);
    const nominalWidth = 250.0;
    const nominalHeight = 180.0;
    final width = nominalWidth * geometry.scale * object.scale;
    final height = nominalHeight * geometry.scale * object.scale;
    return Positioned(
      key: ValueKey('base-camp-object-${object.id}'),
      left: position.dx - width * object.anchor.dx,
      top: position.dy - height * object.anchor.dy,
      width: width,
      height: height,
      child: Transform.rotate(
        angle: object.rotation,
        alignment: Alignment(
          object.anchor.dx * 2 - 1,
          object.anchor.dy * 2 - 1,
        ),
        child: BaseCampMapObjectImage(
          assetId: object.assetId,
          bundledAsset: asset,
          highlightOpacity: highlightOpacity,
        ),
      ),
    );
  }
}

/// A transparent, alpha-aware hit surface over the facility art.  It shares
/// the exact source transform, anchor, scale and rotation used by the image,
/// but never paints a rectangular affordance of its own.
class _BaseCampAlphaFacilityTarget extends StatefulWidget {
  const _BaseCampAlphaFacilityTarget({
    required this.facility,
    required this.object,
    required this.geometry,
    required this.onPressed,
  });

  final BaseCampFacility facility;
  final BaseCampMapObject object;
  final BaseCampMapGeometry geometry;
  final VoidCallback onPressed;

  @override
  State<_BaseCampAlphaFacilityTarget> createState() =>
      _BaseCampAlphaFacilityTargetState();
}

class _BaseCampAlphaFacilityTargetState
    extends State<_BaseCampAlphaFacilityTarget> {
  late final DateTime _animationStartedAt;
  late Future<_BaseCampAlphaMaskSequence?> _mask;

  @override
  void initState() {
    super.initState();
    _animationStartedAt = DateTime.now();
    _mask = _loadMask();
  }

  @override
  void didUpdateWidget(_BaseCampAlphaFacilityTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.object.assetId != widget.object.assetId) {
      _mask = _loadMask();
    }
  }

  Future<_BaseCampAlphaMaskSequence?> _loadMask() async {
    try {
      final bundled = baseCampObjectAssets[widget.object.assetId];
      if (bundled != null) {
        final data = await rootBundle.load(bundled);
        return await _BaseCampAlphaMaskSequence.decode(
          data.buffer.asUint8List(),
        );
      }
      final stored = await BaseCampAssetStore().read(widget.object.assetId);
      return stored == null
          ? null
          : await _BaseCampAlphaMaskSequence.decode(stored.bytes);
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final object = widget.object;
    final position = widget.geometry.sourceToViewport(object.position);
    const nominalWidth = 250.0;
    const nominalHeight = 180.0;
    final width = nominalWidth * widget.geometry.scale * object.scale;
    final height = nominalHeight * widget.geometry.scale * object.scale;
    return Positioned(
      key: ValueKey('base-camp-facility-${widget.facility.id}'),
      left: position.dx - width * object.anchor.dx,
      top: position.dy - height * object.anchor.dy,
      width: width,
      height: height,
      child: Transform.rotate(
        angle: object.rotation,
        alignment: Alignment(
          object.anchor.dx * 2 - 1,
          object.anchor.dy * 2 - 1,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) =>
              FutureBuilder<_BaseCampAlphaMaskSequence?>(
                future: _mask,
                builder: (context, snapshot) {
                  final mask = snapshot.data;
                  if (mask == null) return const SizedBox.expand();
                  return Semantics(
                    button: true,
                    label: '${widget.facility.label} facility',
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapUp: (details) {
                        if (mask.contains(
                          details.localPosition,
                          constraints.biggest,
                          DateTime.now().difference(_animationStartedAt),
                        )) {
                          widget.onPressed();
                        }
                      },
                      child: const SizedBox.expand(),
                    ),
                  );
                },
              ),
        ),
      ),
    );
  }
}

/// Resolves bundled art synchronously and user-imported art from IndexedDB.
/// A missing local binary remains explicit instead of silently substituting a
/// different facility image or modifying persisted object metadata.
class BaseCampMapObjectImage extends StatefulWidget {
  const BaseCampMapObjectImage({
    super.key,
    required this.assetId,
    this.bundledAsset,
    this.highlightOpacity = 0,
  });

  final String assetId;
  final String? bundledAsset;
  final double highlightOpacity;

  @override
  State<BaseCampMapObjectImage> createState() => _BaseCampMapObjectImageState();
}

class _BaseCampMapObjectImageState extends State<BaseCampMapObjectImage> {
  late Future<BaseCampStoredAsset?> _asset;

  @override
  void initState() {
    super.initState();
    _asset = _load();
  }

  @override
  void didUpdateWidget(BaseCampMapObjectImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId ||
        oldWidget.bundledAsset != widget.bundledAsset) {
      _asset = _load();
    }
  }

  Future<BaseCampStoredAsset?> _load() => widget.bundledAsset == null
      ? BaseCampAssetStore().read(widget.assetId)
      : Future<BaseCampStoredAsset?>.value(null);

  @override
  Widget build(BuildContext context) {
    final bundled = widget.bundledAsset;
    if (bundled != null) {
      return _withSelectionGlow(() => _bundledImage(bundled));
    }
    return FutureBuilder<BaseCampStoredAsset?>(
      future: _asset,
      builder: (context, snapshot) {
        final asset = snapshot.data;
        if (asset != null) {
          return _withSelectionGlow(
            () => Image.memory(
              asset.bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.expand();
        }
        return Semantics(
          label: 'Missing Base Camp asset',
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFF68E8F2), width: 1),
              ),
              color: Color(0x66101316),
            ),
            child: Center(
              child: Text(
                'MISSING\nASSET',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB8F8FF), fontSize: 8),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bundledImage(String asset) => Image.asset(
    asset,
    fit: BoxFit.contain,
    gaplessPlayback: true,
    filterQuality: FilterQuality.high,
  );

  Widget _withSelectionGlow(Widget Function() createImage) {
    final opacity = widget.highlightOpacity;
    if (opacity <= 0) return createImage();
    // Each layer uses the image alpha itself, not its rectangular layout box.
    // Animated GIF frames are repainted by Image, so the glow follows their
    // current transparent frame without a separate facility polygon.
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              const Color(0xFF63E8FF).withValues(alpha: .70 * opacity),
              BlendMode.srcIn,
            ),
            child: createImage(),
          ),
        ),
        createImage(),
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            const Color(0xFF63E8FF).withValues(alpha: .22 * opacity),
            BlendMode.srcATop,
          ),
          child: createImage(),
        ),
      ],
    );
  }
}

/// Decodes every frame so an animated facility's hit mask follows its current
/// visible alpha rather than its rectangular image bounds.
@immutable
class _BaseCampAlphaMaskSequence {
  const _BaseCampAlphaMaskSequence(this.frames, this.durations);

  final List<_BaseCampAlphaMask> frames;
  final List<Duration> durations;

  static Future<_BaseCampAlphaMaskSequence?> decode(Uint8List encoded) async {
    final codec = await ui.instantiateImageCodec(encoded);
    try {
      final frames = <_BaseCampAlphaMask>[];
      final durations = <Duration>[];
      for (var index = 0; index < codec.frameCount; index++) {
        final frame = await codec.getNextFrame();
        try {
          final mask = await _BaseCampAlphaMask.fromImage(frame.image);
          if (mask == null) return null;
          frames.add(mask);
          durations.add(frame.duration);
        } finally {
          frame.image.dispose();
        }
      }
      return frames.isEmpty
          ? null
          : _BaseCampAlphaMaskSequence(frames, durations);
    } finally {
      codec.dispose();
    }
  }

  bool contains(Offset position, Size outputSize, Duration elapsed) {
    final total = durations.fold<Duration>(
      Duration.zero,
      (sum, duration) => sum + duration,
    );
    if (total <= Duration.zero) {
      return frames.first.contains(position, outputSize);
    }
    var remaining = elapsed.inMicroseconds % total.inMicroseconds;
    for (var index = 0; index < frames.length; index++) {
      final duration = durations[index].inMicroseconds;
      if (remaining < duration || index == frames.length - 1) {
        return frames[index].contains(position, outputSize);
      }
      remaining -= duration;
    }
    return false;
  }
}

/// A decoded RGBA alpha frame for image-space hit testing.
@immutable
class _BaseCampAlphaMask {
  const _BaseCampAlphaMask(this.width, this.height, this.alpha);

  final int width;
  final int height;
  final Uint8List alpha;

  static Future<_BaseCampAlphaMask?> fromImage(ui.Image image) async {
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rgba == null) return null;
    final pixels = rgba.buffer.asUint8List();
    final alpha = Uint8List(image.width * image.height);
    for (var index = 0; index < alpha.length; index++) {
      alpha[index] = pixels[index * 4 + 3];
    }
    return _BaseCampAlphaMask(image.width, image.height, alpha);
  }

  bool contains(Offset localPosition, Size outputSize) {
    if (outputSize.isEmpty) return false;
    final fitted = applyBoxFit(
      BoxFit.contain,
      Size(width.toDouble(), height.toDouble()),
      outputSize,
    );
    final destination = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & outputSize,
    );
    if (!destination.contains(localPosition)) return false;
    final x =
        ((localPosition.dx - destination.left) / destination.width * width)
            .floor()
            .clamp(0, width - 1);
    final y =
        ((localPosition.dy - destination.top) / destination.height * height)
            .floor()
            .clamp(0, height - 1);
    return alpha[y * width + x] > 12;
  }
}

class BaseCampWalkerPreviewLayer extends StatelessWidget {
  const BaseCampWalkerPreviewLayer({
    super.key,
    required this.elapsed,
    required this.reducedMotion,
    required this.configuration,
    required this.geometry,
  });

  final Duration elapsed;
  final bool reducedMotion;
  final BaseCampMapConfiguration configuration;
  final BaseCampMapGeometry geometry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spriteHeight =
            geometry.scale * BaseCampWalkingSettings.spriteHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            for (final defaultRoute in baseCampWalkerRoutes)
              if (configuration.routes[defaultRoute.id] case final points?)
                _BaseCampGifWalkerPositioned(
                  route: defaultRoute.withSourcePoints(points),
                  pose: baseCampWalkerPoseForRoute(
                    defaultRoute.withSourcePoints(points),
                    elapsed,
                  ),
                  geometry: geometry,
                  spriteHeight: spriteHeight * configuration.soldierScale,
                  reducedMotion: reducedMotion,
                )
              else
                _BaseCampGifWalkerPositioned(
                  route: defaultRoute,
                  pose: baseCampWalkerPose(defaultRoute.id, elapsed),
                  geometry: geometry,
                  spriteHeight: spriteHeight * configuration.soldierScale,
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
    required this.geometry,
    required this.spriteHeight,
    required this.reducedMotion,
  });

  final BaseCampWalkerRoute route;
  final BaseCampWalkerPose pose;
  final BaseCampMapGeometry geometry;
  final double spriteHeight;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final width = spriteHeight * .6;
    final position = geometry.sourceToViewport(pose.sourcePosition);
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
