import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:or_app/core/services/system_diagnostics.dart';
import 'package:or_app/core/widgets/global_touch_ripple.dart';
import 'package:or_app/features/themes/base_camp/base_camp_asset_metrics.dart';
import 'package:or_app/features/themes/base_camp/base_camp_asset_store.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_configuration.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_editor_page.dart';

/// The registered image remains the single visual source. Facility regions are
/// normalised against it so the image, feedback affordances, and hit testing
/// always receive the same [InteractiveViewer] transform.
/// V2.7's approved square BASE CAMP artwork.  Configuration remains in the
/// historic 1280×720 scene coordinate system, so saved editor settings are
/// never rewritten simply because the surrounding artwork became taller.
const baseCampMapAsset = 'assets/images/themes/base_camp/base_camp_map_v3.png';
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

const baseCampWalkerRearUpperRightAsset =
    'assets/images/themes/base_camp/base_camp_walker_rear_upper_right.gif';
const baseCampWalkerFrontAsset =
    'assets/images/themes/base_camp/base_camp_walker_front.gif';

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
  baseCampWalkerRearUpperRightAsset => <String>[
    'assets/images/themes/base_camp/rear_upper_right/frame_00.png',
    'assets/images/themes/base_camp/rear_upper_right/frame_01.png',
    'assets/images/themes/base_camp/rear_upper_right/frame_02.png',
    'assets/images/themes/base_camp/rear_upper_right/frame_03.png',
    'assets/images/themes/base_camp/rear_upper_right/frame_04.png',
  ],
  baseCampWalkerFrontAsset => <String>[
    'assets/images/themes/base_camp/front/frame_00.png',
    'assets/images/themes/base_camp/front/frame_01.png',
    'assets/images/themes/base_camp/front/frame_02.png',
    'assets/images/themes/base_camp/front/frame_03.png',
    'assets/images/themes/base_camp/front/frame_04.png',
  ],
  _ => throw ArgumentError.value(gifAsset, 'gifAsset', 'Unknown walker asset'),
};

Duration baseCampWalkerFrameDuration(String asset) =>
    asset == baseCampWalkerRearUpperRightAsset ||
        asset == baseCampWalkerFrontAsset
    ? const Duration(milliseconds: 160)
    : const Duration(milliseconds: 140);

/// The source dimensions of both the approved map and the white-line route
/// reference. Keeping route points in this coordinate system makes their
/// alignment independent of the dashboard's displayed size and map zoom.
const baseCampMapSourceSize = Size(1280, 720);

/// Pixel dimensions of the supplied V2.7 artwork.  This is deliberately
/// distinct from [baseCampMapSourceSize]: the latter is a durable editor/data
/// coordinate space and must remain stable for existing installations.
const baseCampMapArtworkSize = Size(1254, 1254);

/// The legacy playable scene calibrated inside the new artwork.  Only this
/// affine display mapping changes; persisted routes, facilities, object
/// anchors and FX points all remain expressed in the original coordinate
/// system.  The square artwork itself is always contained, never cropped.
const baseCampLegacySceneInArtwork = Rect.fromLTWH(0, 0, 1254, 900);

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

  /// Horizontal map-source scale used for raster object dimensions so their
  /// approved aspect ratio cannot be stretched by the taller background.
  double get scale =>
      imageRect.width /
      baseCampMapArtworkSize.width *
      baseCampLegacySceneInArtwork.width /
      baseCampMapSourceSize.width;

  double get _artworkScale => imageRect.width / baseCampMapArtworkSize.width;

  double get artworkScale => _artworkScale;

  Offset sourceToViewport(Offset point) => Offset(
    imageRect.left +
        (baseCampLegacySceneInArtwork.left +
                point.dx *
                    baseCampLegacySceneInArtwork.width /
                    baseCampMapSourceSize.width) *
            _artworkScale,
    imageRect.top +
        (baseCampLegacySceneInArtwork.top +
                point.dy *
                    baseCampLegacySceneInArtwork.height /
                    baseCampMapSourceSize.height) *
            _artworkScale,
  );

  Offset viewportToSource(Offset point) => Offset(
    (((point.dx - imageRect.left) / _artworkScale) -
            baseCampLegacySceneInArtwork.left) *
        baseCampMapSourceSize.width /
        baseCampLegacySceneInArtwork.width,
    (((point.dy - imageRect.top) / _artworkScale) -
            baseCampLegacySceneInArtwork.top) *
        baseCampMapSourceSize.height /
        baseCampLegacySceneInArtwork.height,
  );

  /// Converts a point in the square asset canvas to durable source space.
  Offset artworkToSource(Offset point) => viewportToSource(
    Offset(
      imageRect.left + point.dx * _artworkScale,
      imageRect.top + point.dy * _artworkScale,
    ),
  );

  /// Water calibration follows the actual square artwork rather than the
  /// legacy playable scene. This gives the editor access to every pixel of
  /// the new 1254×1254 map without moving any route or facility source data.
  Offset artworkToViewport(Offset point) => Offset(
    imageRect.left + point.dx * _artworkScale,
    imageRect.top + point.dy * _artworkScale,
  );

  Offset viewportToArtwork(Offset point) => Offset(
    (point.dx - imageRect.left) / _artworkScale,
    (point.dy - imageRect.top) / _artworkScale,
  );

  Offset normalizedToViewport(Offset point) => sourceToViewport(
    Offset(
      point.dx * baseCampMapSourceSize.width,
      point.dy * baseCampMapSourceSize.height,
    ),
  );

  static Rect _fittedRect(Size viewport, BoxFit fit) {
    final fitted = applyBoxFit(fit, baseCampMapArtworkSize, viewport);
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

const baseCampRouteA = BaseCampWalkerRoute(
  id: 'route-a',
  sourcePoints: <Offset>[
    Offset(247, 348),
    Offset(316, 319),
    Offset(397, 289),
    Offset(462, 255),
    Offset(514, 229),
  ],
  speed: 50,
  pausePatternSeconds: <double>[3.1, 2.8, 3.4, 2.6],
  initialPhaseSeconds: 4.2,
);

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
  final Stopwatch _mapLoadWatch = Stopwatch();
  bool _mapReadyRecorded = false;

  @override
  void initState() {
    super.initState();
    _mapLoadWatch.start();
    SystemDiagnostics.instance.record(
      'BASE_CAMP',
      'MAP_BACKGROUND_LOAD_START',
      fields: const <String, Object?>{'asset': baseCampMapAsset},
    );
    _selectionPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _selectionVisibility =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 150),
          reverseDuration: const Duration(milliseconds: 250),
        )..addStatusListener((status) {
          if (status == AnimationStatus.dismissed && mounted) {
            _selectionPulse
              ..stop()
              ..value = 0;
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
    if (!_selectionPulse.isAnimating) _selectionPulse.repeat();
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
      _selectionPulse
        ..stop()
        ..value = 0;
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
        // The approved V2.7 asset is square.  Keeping its native ratio and
        // using contain below prevents destructive crop on every device.
        aspectRatio:
            baseCampMapArtworkSize.width / baseCampMapArtworkSize.height,
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
                    final geometry = BaseCampMapGeometry.contain(size);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          baseCampMapAsset,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          frameBuilder: (context, child, frame, synchronous) {
                            if (!_mapReadyRecorded &&
                                (frame != null || synchronous)) {
                              _mapReadyRecorded = true;
                              _mapLoadWatch.stop();
                              recordBaseCampAssetReady(baseCampMapAsset);
                              SystemDiagnostics.instance.record(
                                'BASE_CAMP',
                                'MAP_BACKGROUND_LOAD_COMPLETE',
                                fields: <String, Object?>{
                                  'durationMs':
                                      _mapLoadWatch.elapsedMilliseconds,
                                },
                              );
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                SystemDiagnostics.instance.record(
                                  'BASE_CAMP',
                                  'MAP_DISPLAY_COMPLETE',
                                );
                              });
                            }
                            return child;
                          },
                          errorBuilder: (context, error, stackTrace) {
                            SystemDiagnostics.instance.record(
                              'ASSET',
                              'ASSET_LOAD_FAILED',
                              fields: <String, Object?>{
                                'asset': baseCampMapAsset,
                                'errorType': error.runtimeType.toString(),
                              },
                            );
                            return const SizedBox.expand();
                          },
                        ),
                        IgnorePointer(
                          child: RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _walkerTimeline,
                              builder: (context, _) => BaseCampFoodSmokeLayer(
                                configuration: configuration,
                                geometry: geometry,
                                elapsed: reducedMotion
                                    ? const Duration(seconds: 2)
                                    : Duration(
                                        microseconds:
                                            (_walkerTimeline.value *
                                                    Duration.microsecondsPerDay)
                                                .round(),
                                      ),
                              ),
                            ),
                          ),
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
                        // This must be the final visual MAP layer. Labels
                        // remain input-transparent; the bounded plate targets
                        // and alpha facility targets live in the separate
                        // transformed input stack below.
                        IgnorePointer(
                          child: BaseCampFacilityLabelLayer(
                            configuration: configuration,
                            geometry: geometry,
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
                    final geometry = BaseCampMapGeometry.contain(
                      constraints.biggest,
                    );
                    return Transform(
                      alignment: Alignment.topLeft,
                      transform: _transform.value,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          for (final facility in baseCampFacilities)
                            if (configuration.labels[facility.id]
                                case final label? when label.visible)
                              for (final rect in baseCampLabelTapRects(
                                label,
                                geometry,
                                configuration.objects.values
                                    .map(
                                      (object) => baseCampObjectViewportRect(
                                        object,
                                        geometry,
                                      ),
                                    )
                                    .toList(growable: false),
                              ))
                                _BaseCampFacilityLabelTarget(
                                  facility: facility,
                                  rect: rect,
                                  onPressed: () => _openFacility(facility),
                                ),
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

const baseCampObjectNominalSize = Size(250, 180);

Rect baseCampObjectViewportRect(
  BaseCampMapObject object,
  BaseCampMapGeometry geometry,
) {
  final position = geometry.sourceToViewport(object.position);
  final width = baseCampObjectNominalSize.width * geometry.scale * object.scale;
  final height =
      baseCampObjectNominalSize.height * geometry.scale * object.scale;
  return Rect.fromLTWH(
    position.dx - width * object.anchor.dx,
    position.dy - height * object.anchor.dy,
    width,
    height,
  );
}

/// Converts a normalized local object coordinate into the durable map-source
/// coordinate system, applying its anchor, scale and rotation exactly once.
Offset baseCampObjectLocalToSource(BaseCampMapObject object, Offset local) {
  final relative = Offset(
    (local.dx - object.anchor.dx) *
        baseCampObjectNominalSize.width *
        object.scale,
    (local.dy - object.anchor.dy) *
        baseCampObjectNominalSize.height *
        object.scale,
  );
  final cosine = math.cos(object.rotation);
  final sine = math.sin(object.rotation);
  return object.position +
      Offset(
        relative.dx * cosine - relative.dy * sine,
        relative.dx * sine + relative.dy * cosine,
      );
}

/// Inverse of [baseCampObjectLocalToSource], used by the editor to keep the
/// smoke point stored in FOOD-local coordinates while dragging in map space.
Offset baseCampSourceToObjectLocal(BaseCampMapObject object, Offset source) {
  final relative = source - object.position;
  final cosine = math.cos(object.rotation);
  final sine = math.sin(object.rotation);
  final unrotated = Offset(
    relative.dx * cosine + relative.dy * sine,
    -relative.dx * sine + relative.dy * cosine,
  );
  return Offset(
    unrotated.dx / (baseCampObjectNominalSize.width * object.scale) +
        object.anchor.dx,
    unrotated.dy / (baseCampObjectNominalSize.height * object.scale) +
        object.anchor.dy,
  );
}

/// A bounded, deterministic smoke layer. Particles live in map-source space,
/// so map zoom/pan and FOOD object transforms never detach the chimney trail.
class BaseCampFoodSmokeLayer extends StatelessWidget {
  const BaseCampFoodSmokeLayer({
    super.key,
    required this.configuration,
    required this.geometry,
    required this.elapsed,
  });

  final BaseCampMapConfiguration configuration;
  final BaseCampMapGeometry geometry;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const ValueKey('base-camp-food-smoke'),
    painter: _BaseCampFoodSmokePainter(
      food: configuration.objects['food']!,
      localOrigin: configuration.foodSmokeOrigin,
      effect: configuration.smokeFx,
      geometry: geometry,
      elapsed: elapsed,
    ),
    child: const SizedBox.expand(),
  );
}

class _BaseCampFoodSmokePainter extends CustomPainter {
  const _BaseCampFoodSmokePainter({
    required this.food,
    required this.localOrigin,
    required this.effect,
    required this.geometry,
    required this.elapsed,
  });

  final BaseCampMapObject food;
  final Offset localOrigin;
  final BaseCampSmokeFx effect;
  final BaseCampMapGeometry geometry;
  final Duration elapsed;

  @override
  void paint(Canvas canvas, Size size) {
    if (!effect.visible) return;
    final origin = baseCampObjectLocalToSource(food, localOrigin);
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final rate = 3 * effect.density;
    final newestGeneration = (seconds * rate).floor();
    for (var ageIndex = 0; ageIndex < 18; ageIndex++) {
      final generation = newestGeneration - ageIndex;
      final bornAt = generation / rate;
      final age = seconds - bornAt;
      final life = (2.8 + (generation.abs() % 5) * .3) * effect.lifetime;
      if (age < 0 || age > life) continue;
      final progress = age / life;
      final seed = math.sin(generation * 12.9898) * 43758.5453;
      final unit = seed - seed.floor();
      final swirl =
          math.sin(progress * math.pi * 2 + generation) * 7 * effect.turbulence;
      final drift =
          ((unit * 24 - 12) * effect.spread + swirl * effect.drift) *
          Curves.easeOut.transform(progress);
      final rise =
          (45 + ((unit * 30).round())) *
          effect.riseHeight *
          Curves.easeOut.transform(progress);
      final sourcePosition = origin + Offset(drift, -rise);
      final position = geometry.sourceToViewport(sourcePosition);
      final radius =
          (2 + (generation.abs() % 3)) *
          effect.particleSize *
          (1 + progress * effect.expansion) *
          geometry.scale;
      final alpha =
          (.24 *
                  effect.opacity *
                  (age / .35).clamp(0, 1) *
                  (1 - Curves.easeIn.transform(progress)))
              .clamp(0, .75)
              .toDouble();
      if (alpha <= 0) continue;
      canvas.drawCircle(
        position,
        radius * (1.45 + effect.softness * .35),
        Paint()
          ..color = const Color(0xFFD7D9D6).withValues(alpha: alpha * .42)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            radius * (.9 + effect.softness),
          ),
      );
      canvas.drawCircle(
        position,
        radius,
        Paint()..color = const Color(0xFFD7D9D6).withValues(alpha: alpha),
      );
      canvas.drawCircle(
        position + Offset(radius * .16, -radius * .12),
        radius * .52,
        Paint()
          ..color = const Color(
            0xFF9CA09B,
          ).withValues(alpha: alpha * .38 * effect.contrast),
      );
    }
  }

  @override
  bool shouldRepaint(_BaseCampFoodSmokePainter oldDelegate) =>
      oldDelegate.food != food ||
      oldDelegate.localOrigin != localOrigin ||
      oldDelegate.effect != effect ||
      oldDelegate.geometry != geometry ||
      oldDelegate.elapsed != elapsed;
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

/// Source-space facility plates remain interactive while their connector and
/// target marker travel with the map's image transform.
class BaseCampFacilityLabelLayer extends StatelessWidget {
  const BaseCampFacilityLabelLayer({
    super.key,
    required this.configuration,
    required this.geometry,
  });
  final BaseCampMapConfiguration configuration;
  final BaseCampMapGeometry geometry;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _BaseCampFacilityLabelPainter(configuration, geometry),
  );
}

Rect baseCampFacilityLabelRect(
  BaseCampFacilityLabel label,
  BaseCampMapGeometry geometry,
) {
  final point = geometry.sourceToViewport(label.position);
  final width = 138 * label.scale * geometry.scale;
  final height = 37 * label.scale * geometry.scale;
  return Rect.fromCenter(center: point, width: width, height: height);
}

/// Returns bounded, plate-only input rectangles. Facility object layout boxes
/// are subtracted first so transparent facility margins remain transparent to
/// interaction and alpha hit testing stays the source of truth.
List<Rect> baseCampLabelTapRects(
  BaseCampFacilityLabel label,
  BaseCampMapGeometry geometry,
  List<Rect> objectRects,
) {
  // Facility alpha targets are painted above this bounded target and win any
  // overlap. Keeping this list API allows a future rotated-object clip while
  // retaining the shared plate geometry today.
  return <Rect>[baseCampFacilityLabelRect(label, geometry)];
}

class _BaseCampFacilityLabelTarget extends StatelessWidget {
  const _BaseCampFacilityLabelTarget({
    required this.facility,
    required this.rect,
    required this.onPressed,
  });
  final BaseCampFacility facility;
  final Rect rect;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Positioned(
    left: rect.left,
    top: rect.top,
    width: rect.width,
    height: rect.height,
    child: Semantics(
      button: true,
      label: '${facility.label} label',
      child: GestureDetector(
        key: ValueKey('base-camp-label-target-${facility.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _BaseCampFacilityLabelPainter extends CustomPainter {
  const _BaseCampFacilityLabelPainter(this.configuration, this.geometry);
  final BaseCampMapConfiguration configuration;
  final BaseCampMapGeometry geometry;
  @override
  void paint(Canvas canvas, Size size) {
    for (final facility in baseCampFacilities) {
      final label = configuration.labels[facility.id];
      if (label == null || !label.visible) continue;
      final start = geometry.sourceToViewport(label.connectorStart);
      final end = geometry.sourceToViewport(label.connectorEnd);
      final elbow = Offset.lerp(start, Offset(end.dx, start.dy), label.elbow)!;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(elbow.dx, elbow.dy)
        ..lineTo(end.dx, end.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFE5DFCF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(.7, geometry.scale),
      );
      canvas.drawCircle(
        end,
        math.max(2, geometry.scale * 3),
        Paint()..color = const Color(0xFFE5DFCF),
      );
      final rect = baseCampFacilityLabelRect(label, geometry);
      final radius = Radius.circular(rect.height / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()..color = const Color(0xFF343622),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..color = const Color(0xFFA9A083)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(.7, geometry.scale),
      );
      final dividerX = rect.left + rect.width * .16;
      canvas.drawLine(
        Offset(dividerX, rect.top + rect.height * .18),
        Offset(dividerX, rect.bottom - rect.height * .18),
        Paint()
          ..color = const Color(0xFFA9A083)
          ..strokeWidth = math.max(.7, geometry.scale),
      );
      _paintLabelIcon(
        canvas,
        _facilityIcon(facility.id),
        Rect.fromLTWH(rect.left, rect.top, rect.width * .16, rect.height),
        rect.height * .42,
      );
      _paintLabelText(
        canvas,
        facility.label,
        Rect.fromLTWH(dividerX, rect.top, rect.right - dividerX, rect.height),
        rect.height * .36,
      );
    }
  }

  @override
  bool shouldRepaint(_BaseCampFacilityLabelPainter old) =>
      old.configuration != configuration || old.geometry != geometry;
}

IconData _facilityIcon(String id) => switch (id) {
  'status' => Icons.monitor_heart,
  'food' => Icons.restaurant,
  'training' => Icons.fitness_center,
  'activity' => Icons.directions_walk,
  _ => Icons.flag,
};

void _paintLabelIcon(Canvas canvas, IconData icon, Rect rect, double fontSize) {
  final painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        color: const Color(0xFFF0E8D4),
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: fontSize,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    Offset(
      rect.center.dx - painter.width / 2,
      rect.center.dy - painter.height / 2,
    ),
  );
}

void _paintLabelText(Canvas canvas, String text, Rect rect, double fontSize) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: const Color(0xFFF0E8D4),
        fontFamily: 'ShareTechMono',
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    ),
    maxLines: 1,
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: rect.width);
  painter.paint(
    canvas,
    Offset(
      rect.center.dx - painter.width / 2,
      rect.center.dy - painter.height / 2,
    ),
  );
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
    final width =
        baseCampObjectNominalSize.width * geometry.scale * object.scale;
    final height =
        baseCampObjectNominalSize.height * geometry.scale * object.scale;
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
    final width =
        baseCampObjectNominalSize.width * widget.geometry.scale * object.scale;
    final height =
        baseCampObjectNominalSize.height * widget.geometry.scale * object.scale;
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
  bool _readyRecorded = false;
  late final Stopwatch _loadWatch;

  @override
  void initState() {
    super.initState();
    _loadWatch = Stopwatch()..start();
    SystemDiagnostics.instance.record(
      'ASSET',
      'FACILITY_ASSET_LOAD_START',
      fields: <String, Object?>{'asset': widget.bundledAsset ?? widget.assetId},
    );
    _asset = _load();
  }

  @override
  void didUpdateWidget(BaseCampMapObjectImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId ||
        oldWidget.bundledAsset != widget.bundledAsset) {
      _readyRecorded = false;
      _loadWatch
        ..reset()
        ..start();
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
              frameBuilder: (context, child, frame, synchronous) {
                if (frame != null || synchronous) {
                  _recordReady(widget.assetId, bytes: asset.bytes.length);
                }
                return child;
              },
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
    frameBuilder: (context, child, frame, synchronous) {
      if (frame != null || synchronous) _recordReady(asset);
      return child;
    },
    errorBuilder: (context, error, stackTrace) {
      SystemDiagnostics.instance.record(
        'ASSET',
        'ASSET_LOAD_FAILED',
        fields: <String, Object?>{
          'asset': asset,
          'errorType': error.runtimeType.toString(),
        },
      );
      return const SizedBox.expand();
    },
  );

  void _recordReady(String asset, {int? bytes}) {
    if (_readyRecorded) return;
    _readyRecorded = true;
    _loadWatch.stop();
    recordBaseCampAssetReady(asset);
    SystemDiagnostics.instance.record(
      'ASSET',
      'FACILITY_ASSET_LOAD_COMPLETE',
      fields: <String, Object?>{
        'asset': asset,
        'fileBytes': ?bytes,
        'durationMs': _loadWatch.elapsedMilliseconds,
      },
    );
  }

  Widget _withSelectionGlow(Widget Function() createImage) {
    final opacity = widget.highlightOpacity;
    if (opacity <= 0) return createImage();
    // Each layer uses the image alpha itself, not its rectangular layout box.
    // Animated GIF frames are repainted by Image, so the glow follows their
    // current transparent frame without a separate facility polygon.
    return Stack(
      fit: StackFit.expand,
      children: [
        // The broad layer is deliberately painted first: it expands only the
        // image alpha, never the object's rectangular layout bounds.
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              const Color(0xFF63E8FF).withValues(alpha: .42 * opacity),
              BlendMode.srcIn,
            ),
            child: createImage(),
          ),
        ),
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              const Color(0xFF63E8FF).withValues(alpha: .85 * opacity),
              BlendMode.srcIn,
            ),
            child: createImage(),
          ),
        ),
        createImage(),
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            const Color(0xFF63E8FF).withValues(alpha: .32 * opacity),
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
    // Hit testing never needs the full 1600px facility source. Bounding the
    // dedicated alpha decode avoids retaining a second full-resolution copy
    // of every facility while preserving sub-pixel accuracy at map scale.
    final codec = await ui.instantiateImageCodec(
      encoded,
      targetWidth: 512,
      allowUpscaling: false,
    );
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
            for (final defaultRoute in <BaseCampWalkerRoute>[
              baseCampRouteA,
              ...baseCampWalkerRoutes,
            ])
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
                  assetForPose: defaultRoute.id == 'route-a'
                      ? (pose) => pose.direction.dx >= 0
                            ? baseCampWalkerRearUpperRightAsset
                            : baseCampWalkerFrontAsset
                      : null,
                )
              else
                _BaseCampGifWalkerPositioned(
                  route: defaultRoute,
                  pose: baseCampWalkerPose(defaultRoute.id, elapsed),
                  geometry: geometry,
                  spriteHeight: spriteHeight * configuration.soldierScale,
                  reducedMotion: reducedMotion,
                  assetForPose: defaultRoute.id == 'route-a'
                      ? (pose) => pose.direction.dx >= 0
                            ? baseCampWalkerRearUpperRightAsset
                            : baseCampWalkerFrontAsset
                      : null,
                ),
            for (final soldier in configuration.staticSoldiers)
              if (soldier.visible)
                _BaseCampStaticSoldierPositioned(
                  soldier: soldier,
                  geometry: geometry,
                  elapsed: elapsed,
                  spriteHeight:
                      spriteHeight * configuration.soldierScale * soldier.scale,
                  reducedMotion: reducedMotion,
                ),
          ],
        );
      },
    );
  }
}

class _BaseCampStaticSoldierPositioned extends StatelessWidget {
  const _BaseCampStaticSoldierPositioned({
    required this.soldier,
    required this.geometry,
    required this.elapsed,
    required this.spriteHeight,
    required this.reducedMotion,
  });
  final BaseCampStaticSoldier soldier;
  final BaseCampMapGeometry geometry;
  final Duration elapsed;
  final double spriteHeight;
  final bool reducedMotion;
  @override
  Widget build(BuildContext context) {
    final point = geometry.sourceToViewport(soldier.position);
    final width = spriteHeight * .6;
    final phase =
        elapsed.inMilliseconds / 1000 / soldier.breathingPeriod * math.pi * 2 +
        soldier.id.hashCode;
    final breath = (!reducedMotion && soldier.breathing)
        ? math.sin(phase) * .006 * soldier.breathingIntensity
        : 0.0;
    final asset = switch (soldier.direction) {
      'back' => baseCampWalkerRearUpperRightAsset,
      'right' => baseCampWalkerDownRightAsset,
      'left' => baseCampWalkerUpLeftAsset,
      _ => baseCampWalkerFrontAsset,
    };
    return Positioned(
      key: ValueKey('base-camp-static-soldier-${soldier.id}'),
      left: point.dx - width / 2,
      top: point.dy - spriteHeight,
      width: width,
      height: spriteHeight,
      child: Transform.scale(
        alignment: Alignment.bottomCenter,
        scaleY: 1 + breath,
        child: _BaseCampGifWalker(
          assetPath: asset,
          walking: false,
          reducedMotion: reducedMotion,
        ),
      ),
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
    this.assetForPose,
  });

  final BaseCampWalkerRoute route;
  final BaseCampWalkerPose pose;
  final BaseCampMapGeometry geometry;
  final double spriteHeight;
  final bool reducedMotion;
  final String Function(BaseCampWalkerPose pose)? assetForPose;

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
        assetPath:
            assetForPose?.call(pose) ??
            (pose.usesDownRightAsset
                ? baseCampWalkerDownRightAsset
                : baseCampWalkerUpLeftAsset),
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
    milliseconds:
        baseCampWalkerFrameAssets(widget.assetPath).length *
        baseCampWalkerFrameDuration(widget.assetPath).inMilliseconds,
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
          frameBuilder: (context, child, frame, synchronous) {
            if (frame != null || synchronous) {
              recordBaseCampAssetReady(frames[index]);
            }
            return child;
          },
        );
      },
    );
  }
}
