import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/services/touch_ripple_audio.dart';
import '../../../core/widgets/global_touch_ripple.dart';

enum TrainingAmbientVariant {
  magneticFlux('MAGNETIC FLUX'),
  kineticEngine('KINETIC ENGINE'),
  vectorImpulse('VECTOR IMPULSE');

  const TrainingAmbientVariant(this.label);
  final String label;
}

/// Accumulates only frames during which a KINETIC ENGINE view is active.
///
/// This deliberately owns elapsed mechanical time separately from the ticker
/// that requests paints: a scheduler ticker may be restarted after lifecycle
/// changes without rewinding the connected gear train.
class KineticActiveClock {
  KineticActiveClock({this.maximumUnexpectedGap = const Duration(seconds: 1)});

  final Duration maximumUnexpectedGap;
  // A fresh ticker reports elapsed time from zero. Starting from that epoch
  // retains the first displayed frame interval; resume explicitly clears it.
  Duration? _lastFrameTimestamp = Duration.zero;
  double _elapsedSeconds = 0;
  bool _isActive = true;

  double get elapsedSeconds => _elapsedSeconds;
  bool get isActive => _isActive;

  void advance(Duration timestamp) {
    final previous = _lastFrameTimestamp;
    _lastFrameTimestamp = timestamp;
    if (!_isActive || previous == null) return;
    final delta = timestamp - previous;
    // A regular delayed frame must retain its true phase. A multi-second gap
    // means the browser stopped scheduling without a lifecycle callback; it
    // is treated as an inactive interval rather than a catch-up jump.
    if (delta <= Duration.zero || delta > maximumUnexpectedGap) return;
    _elapsedSeconds += delta.inMicroseconds / Duration.microsecondsPerSecond;
  }

  void pause(Duration timestamp) {
    advance(timestamp);
    _isActive = false;
  }

  void resume() {
    _isActive = true;
    // The first new scheduler timestamp establishes the next frame origin.
    _lastFrameTimestamp = null;
  }
}

/// Stable, PNG-replaceable mechanical geometry.  The same tooth count drives
/// the visible profile, pitch radius, phase and transmission ratio.
class KineticGearGeometry {
  const KineticGearGeometry({
    required this.id,
    required this.center,
    required this.toothCount,
    required this.module,
    required this.pitchRadius,
    required this.rootRadius,
    required this.tipRadius,
    required this.phaseOffset,
    required this.driveRatio,
    this.parentId,
  });

  final String id;
  final Offset center;
  final int toothCount;
  final double module;
  final double pitchRadius;
  final double rootRadius;
  final double tipRadius;
  final double phaseOffset;
  final double driveRatio;
  final String? parentId;

  int get renderedToothTipCount => toothCount;

  double phaseAt(double drivePhase) => phaseOffset + driveRatio * drivePhase;
}

/// The tooth profile remains driven by [KineticGearGeometry]; this only
/// selects the anime-mechanical construction painted inside that profile.
/// Keeping it separate makes individual gear bodies PNG-replaceable later
/// without changing pivots, tooth counts, or transmission timing.
enum KineticGearVisualVariant {
  openSpoke,
  thinRim,
  ringShortSpoke,
  cutoutDisc,
  pinion,
  asymmetric,
}

/// A locomotive-style coupling rod driven by one primary gear. All three
/// crank pins share the same eccentric vector, so both rod spans remain
/// exactly constant through a complete revolution.
class KineticSteamLinkagePose {
  const KineticSteamLinkagePose({
    required this.axleCenters,
    required this.crankPins,
    required this.crankRadius,
    required this.crosshead,
    required this.guideStart,
    required this.guideEnd,
    required this.connectingRodLength,
  });

  final List<Offset> axleCenters;
  final List<Offset> crankPins;
  final double crankRadius;
  final Offset crosshead;
  final Offset guideStart;
  final Offset guideEnd;
  final double connectingRodLength;

  List<double> get rodLengths => [
    for (var i = 1; i < crankPins.length; i++)
      (crankPins[i] - crankPins[i - 1]).distance,
  ];
}

/// A four-bar-like rocker driven from an eccentric gear pin. The coupler and
/// rocker endpoints are found from two intersecting circles, preserving both
/// member lengths instead of visually stretching a decorative line.
class KineticRockerLinkagePose {
  const KineticRockerLinkagePose({
    required this.crankPin,
    required this.fixedPivot,
    required this.rockerJoint,
    required this.couplerLength,
    required this.rockerLength,
  });

  final Offset crankPin;
  final Offset fixedPivot;
  final Offset rockerJoint;
  final double couplerLength;
  final double rockerLength;
}

/// A fixed, machined support for a linkage pivot.  It deliberately exposes
/// only fixed anchors: moving crank pins stay free to rotate or reciprocate.
class KineticLinkageSupportGeometry {
  const KineticLinkageSupportGeometry({
    required this.id,
    required this.anchor,
    required this.mounts,
    required this.role,
  });

  final String id;
  final Offset anchor;
  final List<Offset> mounts;
  final String role;
}

/// The REPORT SYNC transmission is a pair of constant-length open belts over
/// three fixed, coaxial wheel centers.  The center wheel uses two grooves so
/// each belt remains independently readable and mechanically plausible.
class KineticReportSyncTransmissionPose {
  const KineticReportSyncTransmissionPose({
    required this.axleCenters,
    required this.pulleyRadius,
    required this.beltLoopLengths,
    required this.phase,
  });

  final List<Offset> axleCenters;
  final double pulleyRadius;
  final List<double> beltLoopLengths;
  final double phase;
}

/// A sampled position on one closed, equal-radius open-belt path.  The path
/// is measured by arc length so surface ribs can travel continuously across
/// straight and wrapped segments with the same phase.
class _OpenBeltPathSample {
  const _OpenBeltPathSample(this.position, this.tangent);

  final Offset position;
  final Offset tangent;
}

/// The two REPORT SYNC belts use equal-radius pulleys.  This retains the
/// frozen V11.7 length `2d + 2πr` while providing a real continuous route for
/// the belt body and moving surface details.
class _OpenBeltLoop {
  _OpenBeltLoop(this.start, this.end, this.radius)
    : span = (end - start).distance,
      axis = (end - start).distance == 0
          ? const Offset(1, 0)
          : (end - start) / (end - start).distance {
    normal = Offset(-axis.dy, axis.dx);
    normalAngle = math.atan2(normal.dy, normal.dx);
    loopLength = span * 2 + 2 * math.pi * radius;
  }

  final Offset start;
  final Offset end;
  final double radius;
  final double span;
  final Offset axis;
  late final Offset normal;
  late final double normalAngle;
  late final double loopLength;

  bool get isValid => span > radius * 2.2 && radius > 0;

  _OpenBeltPathSample sampleAt(double distance) {
    var cursor = distance % loopLength;
    if (cursor < 0) cursor += loopLength;
    if (cursor <= span) {
      return _OpenBeltPathSample(start + normal * radius + axis * cursor, axis);
    }
    cursor -= span;
    if (cursor <= math.pi * radius) {
      final angle = normalAngle + cursor / radius;
      return _OpenBeltPathSample(
        end + Offset(math.cos(angle), math.sin(angle)) * radius,
        Offset(-math.sin(angle), math.cos(angle)),
      );
    }
    cursor -= math.pi * radius;
    if (cursor <= span) {
      return _OpenBeltPathSample(end - normal * radius - axis * cursor, -axis);
    }
    cursor -= span;
    final angle = normalAngle + math.pi + cursor / radius;
    return _OpenBeltPathSample(
      start + Offset(math.cos(angle), math.sin(angle)) * radius,
      Offset(-math.sin(angle), math.cos(angle)),
    );
  }

  Path get path {
    final result = Path();
    final segments = math.max(8, (radius * 1.45).round());
    result.moveTo(start.dx + normal.dx * radius, start.dy + normal.dy * radius);
    result.lineTo(end.dx + normal.dx * radius, end.dy + normal.dy * radius);
    for (var index = 1; index <= segments; index++) {
      final sample = sampleAt(span + math.pi * radius * index / segments);
      result.lineTo(sample.position.dx, sample.position.dy);
    }
    result.lineTo(start.dx - normal.dx * radius, start.dy - normal.dy * radius);
    for (var index = 1; index <= segments; index++) {
      final sample = sampleAt(
        span * 2 + math.pi * radius + math.pi * radius * index / segments,
      );
      result.lineTo(sample.position.dx, sample.position.dy);
    }
    result.close();
    return result;
  }

  Path edgePath(double offset) {
    final result = Path();
    const samples = 40;
    for (var index = 0; index <= samples; index++) {
      final sample = sampleAt(loopLength * index / samples);
      final edgeNormal = Offset(-sample.tangent.dy, sample.tangent.dx);
      final point = sample.position + edgeNormal * offset;
      if (index == 0) {
        result.moveTo(point.dx, point.dy);
      } else {
        result.lineTo(point.dx, point.dy);
      }
    }
    result.close();
    return result;
  }
}

/// Static, PNG-replaceable structure behind the two V7 gear layers.  It has
/// no drive state, so adding it cannot affect transmission geometry or motion.
class KineticBaseplateGeometry {
  const KineticBaseplateGeometry({
    required this.plate,
    required this.mountGearIds,
    required this.bridgeGearIds,
  });

  /// A normalized, irregular plate outline.  Keeping this normalized makes
  /// the machine scale with the scrollable TRAINING ambient extent.
  final List<Offset> plate;
  final List<String> mountGearIds;
  final List<(String, String)> bridgeGearIds;
}

/// Deterministic visual state for one of V11.6's existing luminous hubs.
/// It is independent from gear rotation so transmission timing stays frozen.
class KineticHubGlowState {
  const KineticHubGlowState({required this.phase, required this.color});

  final double phase;
  final Color color;
}

/// Static cover metadata used by focused geometry tests and the painter.
/// Coordinates are normalized to the fixed TRAINING ambient viewport.
class KineticMechanicalCoverGeometry {
  const KineticMechanicalCoverGeometry({
    required this.id,
    required this.bounds,
    required this.mounts,
    required this.apertureCount,
  });

  final String id;
  final Rect bounds;
  final List<Offset> mounts;
  final int apertureCount;
}

class TrainingAmbientComparison extends StatefulWidget {
  const TrainingAmbientComparison({
    super.key,
    required this.variant,
    this.debugTime,
    this.kineticImageProvider,
    this.showKineticImage = true,
  });
  final TrainingAmbientVariant variant;
  final double? debugTime;

  /// Test-only seams for exercising the synchronous fallback while a browser
  /// image decode is delayed or unavailable. Production always uses the WebP.
  @visibleForTesting
  final ImageProvider<Object>? kineticImageProvider;
  @visibleForTesting
  final bool showKineticImage;

  static const kineticEngineBackgroundAsset =
      'assets/images/training/kinetic_engine_v9_background_q90.webp';

  /// V11.1 profile parameters. Pitch circles remain frozen; only the radial
  /// envelope and angular occupancy around each pitch circle change.
  static const v11ToothRootDedendum = .95;
  static const v11ToothTipAddendum = 1.35;
  static const v11ToothTipAngularWidthFraction = .49;
  static const kineticToothRootDedendum = 1.45;
  static const kineticToothTipAddendum = 1.85;
  static const kineticToothTipAngularWidthFraction = .33;
  static const kineticHubGlowPeriodSeconds = 24.0;

  static double kineticHubGlowPhaseOffsetFor(String gearId) {
    var signature = 17;
    for (var i = 0; i < gearId.length; i++) {
      signature = (signature * 37 + gearId.codeUnitAt(i) * (i + 3)) % 997;
    }
    return signature / 997;
  }

  static KineticHubGlowState kineticHubGlowStateFor(
    String gearId,
    double time,
  ) {
    final phase =
        (time / kineticHubGlowPeriodSeconds +
            kineticHubGlowPhaseOffsetFor(gearId)) %
        1;
    const orange = Color(0xffff9f43);
    const white = Color(0xffeefcff);
    const neonBlue = Color(0xff35dcff);
    final segment = phase * 4;
    final color = switch (segment.floor()) {
      0 => Color.lerp(orange, white, segment)!,
      1 => Color.lerp(white, neonBlue, segment - 1)!,
      2 => Color.lerp(neonBlue, white, segment - 2)!,
      _ => Color.lerp(white, orange, segment - 3)!,
    };
    return KineticHubGlowState(phase: phase, color: color);
  }

  static List<KineticMechanicalCoverGeometry> kineticMechanicalCoversFor(
    Size size,
  ) => [
    KineticMechanicalCoverGeometry(
      id: 'upper-right-support-bridge',
      bounds: Rect.fromLTRB(size.width * .57, 0, size.width, size.height * .31),
      mounts: [
        Offset(size.width * .78, size.height * .105),
        Offset(size.width * .91, size.height * .225),
      ],
      apertureCount: 2,
    ),
    KineticMechanicalCoverGeometry(
      id: 'lower-left-curved-cover',
      bounds: Rect.fromLTRB(
        0,
        size.height * .68,
        size.width * .48,
        size.height,
      ),
      mounts: [
        Offset(size.width * .12, size.height * .865),
        Offset(size.width * .35, size.height * .925),
      ],
      apertureCount: 3,
    ),
  ];

  /// V6.2 inventory. Each entry becomes one visibly emitted tooth profile.
  static const kineticGearToothCounts = <int>[
    40,
    24,
    14,
    30,
    16,
    28,
    12,
    32,
    18,
    26,
    20,
    34,
    14,
    24,
    16,
    30,
    12,
    28,
    18,
    22,
    16,
    26,
  ];

  static double motionSignatureFor(
    TrainingAmbientVariant variant,
    double time,
  ) {
    switch (variant) {
      case TrainingAmbientVariant.magneticFlux:
        return math.sin(time * .31) + math.cos(time * .17 + .8);
      case TrainingAmbientVariant.kineticEngine:
        return math.sin(time * .74) + math.cos(time * .29 + 1.7);
      case TrainingAmbientVariant.vectorImpulse:
        return math.sin(time * 1.19) + math.cos(time * .41 + .35);
    }
  }

  /// External gears use the tooth-count ratio and turn in opposite directions.
  /// Kept public so the mechanical relationship is regression-tested without
  /// coupling a test to painter pixels.
  static double meshedAngularVelocity({
    required double driveVelocity,
    required int driveTeeth,
    required int drivenTeeth,
  }) => -driveVelocity * driveTeeth / drivenTeeth;

  static double kineticDrivePhase(double time) =>
      .72 * time + .11 / .17 * (1 - math.cos(time * .17));

  /// First derivative of [kineticDrivePhase].  Keeping it explicit makes the
  /// continuous-clock contract testable at former controller boundaries.
  static double kineticDriveAngularVelocity(double time) =>
      .72 + .11 * math.sin(time * .17);

  /// Builds one connected, vertically distributed train for the actual
  /// scrollable painting extent. All gears share one module and every child
  /// pivot is derived from its parent's pitch radius.
  static List<KineticGearGeometry> kineticGearGeometryFor(Size size) {
    // The scroll extent controls scale as well as width: a long TRAINING page
    // receives a physically larger connected train rather than a fixed-height
    // cluster followed by empty ambient space.
    final module = math.max(
      1.18,
      math.max(size.width * .0038, size.height * .0015),
    );
    KineticGearGeometry root(
      String id,
      Offset center,
      int teeth,
    ) => KineticGearGeometry(
      id: id,
      center: center,
      toothCount: teeth,
      module: module,
      pitchRadius: module * teeth,
      rootRadius:
          module * (teeth - TrainingAmbientComparison.kineticToothRootDedendum),
      tipRadius:
          module * (teeth + TrainingAmbientComparison.kineticToothTipAddendum),
      phaseOffset: .08,
      driveRatio: 1,
    );
    KineticGearGeometry mesh(
      KineticGearGeometry parent,
      String id,
      double angle,
      int teeth,
    ) {
      final pitchRadius = module * teeth;
      final ratio = -parent.driveRatio * parent.toothCount / teeth;
      return KineticGearGeometry(
        id: id,
        parentId: parent.id,
        center:
            parent.center +
            Offset.fromDirection(angle, parent.pitchRadius + pitchRadius),
        toothCount: teeth,
        module: module,
        pitchRadius: pitchRadius,
        rootRadius:
            module *
            (teeth - TrainingAmbientComparison.kineticToothRootDedendum),
        tipRadius:
            module *
            (teeth + TrainingAmbientComparison.kineticToothTipAddendum),
        phaseOffset:
            angle +
            math.pi -
            math.pi / teeth -
            parent.phaseOffset * parent.toothCount / teeth,
        driveRatio: ratio,
      );
    }

    final drive = root('main-drive', Offset(size.width * .48, module * 43), 40);
    final specs = <(String, double, int)>[
      ('upper-left', 2.44, 24),
      ('left-pinion', 1.48, 14),
      ('left-crown', 2.35, 30),
      ('left-transfer', 1.16, 16),
      ('upper-right', -.36, 28),
      ('right-pinion', 1.44, 12),
      ('right-crown', .56, 32),
      ('right-transfer', 1.72, 18),
      ('mid-drive', .96, 26),
      ('mid-pinion', 2.06, 20),
      ('mid-crown', 1.18, 34),
      ('lower-left', 2.12, 14),
      ('lower-center', .92, 24),
      ('lower-pinion', 1.96, 16),
      ('lower-crown', 1.12, 30),
      ('output-pinion', 2.24, 12),
      ('output-crown', 1.04, 28),
      ('escapement', 2.12, 18),
      ('bottom-drive', 1.04, 22),
      ('bottom-pinion', 2.20, 16),
      ('bottom-crown', 1.10, 26),
    ];
    final gears = <KineticGearGeometry>[drive];
    for (final spec in specs) {
      gears.add(mesh(gears.last, spec.$1, spec.$2, spec.$3));
    }
    return gears;
  }

  /// Four independent, low-contrast drive groups behind the V6.2 primary
  /// train. They use tree-shaped meshes, rather than a second vertical chain.
  /// Each stable pivot can later be selectively replaced with a PNG asset.
  static List<KineticGearGeometry> kineticBackgroundGearGeometryFor(Size size) {
    final module = (size.width * .0044).clamp(1.22, 1.82);

    KineticGearGeometry root(
      String id,
      Offset center,
      int teeth,
      double driveRatio,
      double phase,
    ) => KineticGearGeometry(
      id: id,
      center: center,
      toothCount: teeth,
      module: module,
      pitchRadius: module * teeth,
      rootRadius:
          module * (teeth - TrainingAmbientComparison.kineticToothRootDedendum),
      tipRadius:
          module * (teeth + TrainingAmbientComparison.kineticToothTipAddendum),
      phaseOffset: phase,
      driveRatio: driveRatio,
    );

    KineticGearGeometry mesh(
      KineticGearGeometry parent,
      String id,
      double angle,
      int teeth,
    ) {
      final pitchRadius = module * teeth;
      return KineticGearGeometry(
        id: id,
        parentId: parent.id,
        center:
            parent.center +
            Offset.fromDirection(angle, parent.pitchRadius + pitchRadius),
        toothCount: teeth,
        module: module,
        pitchRadius: pitchRadius,
        rootRadius:
            module *
            (teeth - TrainingAmbientComparison.kineticToothRootDedendum),
        tipRadius:
            module *
            (teeth + TrainingAmbientComparison.kineticToothTipAddendum),
        phaseOffset:
            angle +
            math.pi -
            math.pi / teeth -
            parent.phaseOffset * parent.toothCount / teeth,
        driveRatio: -parent.driveRatio * parent.toothCount / teeth,
      );
    }

    List<KineticGearGeometry> cluster(
      String id,
      Offset center,
      double direction,
      double driveRatio,
      double phase,
    ) {
      final drive = root('$id-drive', center, 34, driveRatio, phase);
      final upper = mesh(drive, '$id-upper', direction - .85, 16);
      final outer = mesh(drive, '$id-outer', direction + .35, 24);
      final lower = mesh(drive, '$id-lower', direction + 1.52, 14);
      final transfer = mesh(upper, '$id-transfer', direction - 1.72, 22);
      final pinion = mesh(outer, '$id-pinion', direction + .96, 12);
      final crown = mesh(lower, '$id-crown', direction + 2.44, 20);
      final escape = mesh(transfer, '$id-escape', direction - .54, 14);
      return [drive, upper, outer, lower, transfer, pinion, crown, escape];
    }

    return [
      ...cluster(
        'background-north-left',
        Offset(size.width * .03, size.height * .105),
        .18,
        .27,
        .34,
      ),
      ...cluster(
        'background-north-right',
        Offset(size.width * .95, size.height * .31),
        math.pi - .26,
        -.21,
        1.08,
      ),
      ...cluster(
        'background-south-left',
        Offset(size.width * .06, size.height * .57),
        .06,
        .24,
        2.22,
      ),
      ...cluster(
        'background-south-right',
        Offset(size.width * .94, size.height * .83),
        math.pi - .12,
        -.25,
        2.88,
      ),
    ];
  }

  /// V10's gear interiors vary by stable identity, not by frame. The existing
  /// 54 pitch circles and tooth profiles therefore remain mechanically frozen.
  static KineticGearVisualVariant kineticGearVisualVariantFor(
    KineticGearGeometry gear,
    int index, {
    bool background = false,
  }) {
    if (gear.toothCount <= 14) return KineticGearVisualVariant.pinion;
    const deliberatePrimaryAssignments = <String, KineticGearVisualVariant>{
      'main-drive': KineticGearVisualVariant.ringShortSpoke,
      'upper-left': KineticGearVisualVariant.openSpoke,
      'left-crown': KineticGearVisualVariant.cutoutDisc,
      'left-transfer': KineticGearVisualVariant.thinRim,
      'upper-right': KineticGearVisualVariant.asymmetric,
      'right-crown': KineticGearVisualVariant.ringShortSpoke,
      'right-transfer': KineticGearVisualVariant.thinRim,
      'mid-drive': KineticGearVisualVariant.cutoutDisc,
      'mid-pinion': KineticGearVisualVariant.openSpoke,
      'mid-crown': KineticGearVisualVariant.ringShortSpoke,
    };
    final deliberate = deliberatePrimaryAssignments[gear.id];
    if (deliberate != null) return deliberate;
    final stableSeed = gear.id.codeUnits.fold<int>(
      index,
      (sum, code) => sum + code,
    );
    const variants = <KineticGearVisualVariant>[
      KineticGearVisualVariant.openSpoke,
      KineticGearVisualVariant.thinRim,
      KineticGearVisualVariant.ringShortSpoke,
      KineticGearVisualVariant.cutoutDisc,
      KineticGearVisualVariant.asymmetric,
    ];
    // Rear gears favour open negative space so they remain subordinate.
    final adjusted = background ? stableSeed + 1 : stableSeed;
    return variants[adjusted % variants.length];
  }

  /// V11 assigns a deliberate, visibly different spoke count to every
  /// non-pinion silhouette. It is stable per identity, never per frame.
  static int kineticSpokeCountFor(KineticGearGeometry gear, int index) {
    if (gear.toothCount <= 14) return 3;
    const spokeCounts = [3, 4, 5, 6, 8];
    final stableSeed = gear.id.codeUnits.fold<int>(
      index,
      (sum, code) => sum + code,
    );
    return spokeCounts[stableSeed % spokeCounts.length];
  }

  /// V11.2's accepted inner rim boundaries. V11.3 changes only the material
  /// and the interior construction drawn inside these frozen boundaries.
  static double kineticRimInnerRadiusFactorFor(
    KineticGearVisualVariant variant,
  ) => switch (variant) {
    KineticGearVisualVariant.openSpoke => .85,
    KineticGearVisualVariant.thinRim => .88,
    KineticGearVisualVariant.ringShortSpoke => .86,
    KineticGearVisualVariant.cutoutDisc => .84,
    KineticGearVisualVariant.pinion => .76,
    KineticGearVisualVariant.asymmetric => .84,
  };

  static KineticSteamLinkagePose kineticSteamLinkagePoseFor(
    KineticGearGeometry driveGear,
    double drivePhase,
  ) {
    final crankRadius = math.min(
      driveGear.pitchRadius * .29,
      driveGear.module * 9.5,
    );
    final spacing = driveGear.module * 55;
    final centers = <Offset>[
      driveGear.center - Offset(spacing * 2, 0),
      driveGear.center - Offset(spacing, 0),
      driveGear.center,
    ];
    final eccentric = Offset.fromDirection(
      driveGear.phaseAt(drivePhase),
      crankRadius,
    );
    final crankPins = [for (final center in centers) center + eccentric];
    final guideY = driveGear.center.dy - crankRadius * 1.55;
    final connectingRodLength = spacing * 1.18;
    final drivingPin = crankPins.last;
    final vertical = guideY - drivingPin.dy;
    final travel = math.sqrt(
      math.max(
        0,
        connectingRodLength * connectingRodLength - vertical * vertical,
      ),
    );
    final crosshead = Offset(drivingPin.dx + travel, guideY);
    return KineticSteamLinkagePose(
      axleCenters: centers,
      crankPins: crankPins,
      crankRadius: crankRadius,
      crosshead: crosshead,
      guideStart: Offset(driveGear.center.dx + spacing * .42, guideY),
      guideEnd: Offset(driveGear.center.dx + spacing * 1.52, guideY),
      connectingRodLength: connectingRodLength,
    );
  }

  static KineticRockerLinkagePose kineticRockerLinkagePoseFor(
    KineticGearGeometry driveGear,
    double drivePhase,
  ) {
    final crankPin =
        driveGear.center +
        Offset.fromDirection(
          driveGear.phaseAt(drivePhase) + .42,
          driveGear.pitchRadius * .42,
        );
    final fixedPivot =
        driveGear.center +
        Offset(-driveGear.module * 42, driveGear.module * 34);
    final couplerLength = driveGear.module * 38;
    final rockerLength = driveGear.module * 31;
    final delta = crankPin - fixedPivot;
    final distance = delta.distance;
    final along =
        (rockerLength * rockerLength -
            couplerLength * couplerLength +
            distance * distance) /
        (2 * distance);
    final height = math.sqrt(
      math.max(0, rockerLength * rockerLength - along * along),
    );
    final unit = delta / distance;
    final perpendicular = Offset(-unit.dy, unit.dx);
    final rockerJoint = fixedPivot + unit * along + perpendicular * height;
    return KineticRockerLinkagePose(
      crankPin: crankPin,
      fixedPivot: fixedPivot,
      rockerJoint: rockerJoint,
      couplerLength: couplerLength,
      rockerLength: rockerLength,
    );
  }

  /// The RECORD-side support attaches to the rocker’s actual fixed pivot,
  /// never to the drive gear’s rotating crank pin.
  static KineticLinkageSupportGeometry kineticRecordRootSupportFor(
    KineticGearGeometry driveGear,
  ) {
    final pose = kineticRockerLinkagePoseFor(driveGear, 0);
    final scale = driveGear.module;
    final anchor = pose.fixedPivot;
    return KineticLinkageSupportGeometry(
      id: 'record-rocker-root-support',
      anchor: anchor,
      role: 'fixed-rocker-pivot',
      mounts: [
        anchor + Offset(-scale * 8.7, scale * 8.2),
        anchor + Offset(scale * 8.1, scale * 7.4),
        anchor + Offset(-scale * 5.8, -scale * 7.2),
      ],
    );
  }

  /// REPORT SYNC has three fixed wheel centers.  Two equal-radius open belts
  /// connect left→center and center→right; with fixed centers their loop
  /// lengths are invariant at every animation phase.
  static KineticReportSyncTransmissionPose kineticReportSyncTransmissionPoseFor(
    KineticGearGeometry driveGear,
    double drivePhase,
  ) {
    final steam = kineticSteamLinkagePoseFor(driveGear, drivePhase);
    final pulleyRadius = driveGear.module * 7.4;
    final beltLoopLengths = <double>[
      for (var i = 0; i < steam.axleCenters.length - 1; i++)
        2 * (steam.axleCenters[i + 1] - steam.axleCenters[i]).distance +
            2 * math.pi * pulleyRadius,
    ];
    return KineticReportSyncTransmissionPose(
      axleCenters: steam.axleCenters,
      pulleyRadius: pulleyRadius,
      beltLoopLengths: beltLoopLengths,
      phase: driveGear.phaseAt(drivePhase),
    );
  }

  static List<KineticLinkageSupportGeometry>
  kineticReportSyncSupportGeometryFor(KineticGearGeometry driveGear) {
    final transmission = kineticReportSyncTransmissionPoseFor(driveGear, 0);
    final scale = driveGear.module;
    const ids = [
      'report-sync-left-support',
      'report-sync-center-support',
      'report-sync-right-support',
    ];
    const roles = [
      'left-fixed-pulley',
      'center-dual-groove-pulley',
      'right-drive-flange',
    ];
    return [
      for (var i = 0; i < transmission.axleCenters.length; i++)
        KineticLinkageSupportGeometry(
          id: ids[i],
          anchor: transmission.axleCenters[i],
          role: roles[i],
          mounts: [
            transmission.axleCenters[i] + Offset(-scale * 7.3, scale * 8.1),
            transmission.axleCenters[i] + Offset(scale * 7.3, scale * 8.1),
          ],
        ),
    ];
  }

  /// V8 baseplate topology. Plates overlap but are deliberately broken into
  /// separate machined sections instead of becoming a decorative rectangle.
  /// Every mounting point resolves to a V7 primary or background gear pivot.
  static List<KineticBaseplateGeometry> kineticBaseplateGeometryFor(
    Size size, {
    List<KineticGearGeometry>? primaryGears,
    List<KineticGearGeometry>? backgroundGears,
  }) {
    final primary = primaryGears ?? kineticGearGeometryFor(size);
    final background =
        backgroundGears ?? kineticBackgroundGearGeometryFor(size);
    final ids = {
      for (final gear in [...primary, ...background]) gear.id,
    };
    final plates = <KineticBaseplateGeometry>[
      const KineticBaseplateGeometry(
        plate: [
          Offset(-.08, .00),
          Offset(.38, -.02),
          Offset(.56, .16),
          Offset(.47, .31),
          Offset(.17, .35),
          Offset(-.04, .22),
        ],
        mountGearIds: ['main-drive', 'upper-left', 'upper-right'],
        bridgeGearIds: [
          ('main-drive', 'upper-left'),
          ('main-drive', 'upper-right'),
        ],
      ),
      const KineticBaseplateGeometry(
        plate: [
          Offset(.56, .08),
          Offset(1.08, .05),
          Offset(1.06, .38),
          Offset(.79, .47),
          Offset(.57, .33),
        ],
        mountGearIds: [
          'background-north-right-drive',
          'background-north-right-outer',
          'right-crown',
        ],
        bridgeGearIds: [
          ('background-north-right-drive', 'background-north-right-outer'),
          ('right-crown', 'right-transfer'),
        ],
      ),
      const KineticBaseplateGeometry(
        plate: [
          Offset(-.08, .31),
          Offset(.34, .28),
          Offset(.58, .45),
          Offset(.45, .68),
          Offset(.09, .70),
          Offset(-.06, .54),
        ],
        mountGearIds: [
          'left-crown',
          'mid-drive',
          'background-south-left-drive',
        ],
        bridgeGearIds: [
          ('left-crown', 'left-transfer'),
          ('mid-drive', 'mid-crown'),
          ('background-south-left-drive', 'background-south-left-outer'),
        ],
      ),
      const KineticBaseplateGeometry(
        plate: [
          Offset(.52, .48),
          Offset(1.07, .43),
          Offset(1.05, .78),
          Offset(.77, .89),
          Offset(.48, .75),
        ],
        mountGearIds: [
          'output-crown',
          'bottom-drive',
          'background-south-right-drive',
        ],
        bridgeGearIds: [
          ('output-crown', 'output-pinion'),
          ('bottom-drive', 'bottom-crown'),
          ('background-south-right-drive', 'background-south-right-upper'),
        ],
      ),
      const KineticBaseplateGeometry(
        plate: [
          Offset(-.07, .69),
          Offset(.44, .66),
          Offset(.61, .84),
          Offset(.51, 1.05),
          Offset(.04, 1.04),
          Offset(-.08, .89),
        ],
        mountGearIds: [
          'escapement',
          'bottom-crown',
          'background-south-left-crown',
        ],
        bridgeGearIds: [
          ('escapement', 'bottom-drive'),
          ('background-south-left-crown', 'background-south-left-lower'),
        ],
      ),
    ];
    assert(
      plates.expand((plate) => plate.mountGearIds).every(ids.contains),
      'Baseplate mounts must resolve to an existing V7 gear pivot.',
    );
    assert(
      plates
          .expand((plate) => plate.bridgeGearIds)
          .every(
            (bridge) => ids.contains(bridge.$1) && ids.contains(bridge.$2),
          ),
      'Baseplate bridges must resolve to existing V7 gear pivots.',
    );
    return plates;
  }

  @override
  State<TrainingAmbientComparison> createState() =>
      _TrainingAmbientComparisonState();
}

class _TrainingAmbientComparisonState extends State<TrainingAmbientComparison>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _kineticBackgroundImage = AssetImage(
    TrainingAmbientComparison.kineticEngineBackgroundAsset,
  );
  late final Ticker _ticker;
  final KineticActiveClock _machineClock = KineticActiveClock();
  Duration? _lastTickerElapsed;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  var _imageFailed = false;

  ImageProvider<Object> get _imageProvider =>
      widget.kineticImageProvider ?? _kineticBackgroundImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    KineticFirstFrameInstrumentation.ambientInit();
    _ticker = createTicker(_onFrame)..start();
  }

  void _onFrame(Duration elapsed) {
    _lastTickerElapsed = elapsed;
    _machineClock.advance(elapsed);
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _machineClock.resume();
        if (!_ticker.isActive) _ticker.start();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        final timestamp = _lastTickerElapsed;
        if (timestamp != null) _machineClock.pause(timestamp);
        _ticker.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.variant == TrainingAmbientVariant.kineticEngine) {
      _resolveKineticImage();
    }
  }

  @override
  void didUpdateWidget(covariant TrainingAmbientComparison oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kineticImageProvider != widget.kineticImageProvider ||
        oldWidget.showKineticImage != widget.showKineticImage) {
      _stopImageListening();
      _imageFailed = false;
      if (widget.variant == TrainingAmbientVariant.kineticEngine) {
        _resolveKineticImage();
      }
    }
  }

  void _resolveKineticImage() {
    if (!widget.showKineticImage || _imageStream != null) return;
    KineticFirstFrameInstrumentation.imageResolveStart();
    final stream = _imageProvider.resolve(
      createLocalImageConfiguration(context),
    );
    _imageStream = stream;
    _imageListener = ImageStreamListener(
      (_, _) {
        KineticFirstFrameInstrumentation.imageReady();
      },
      onError: (Object error, StackTrace? stackTrace) {
        KineticFirstFrameInstrumentation.imageError(error);
        if (mounted) setState(() => _imageFailed = true);
      },
    );
    stream.addListener(_imageListener!);
  }

  void _stopImageListening() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    _imageStream = null;
    _imageListener = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopImageListening();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.variant == TrainingAmbientVariant.kineticEngine)
            CustomPaint(
              key: const ValueKey('kinetic-first-frame-fallback'),
              painter: const _KineticFirstFrameFallbackPainter(),
              child: const SizedBox.expand(),
            ),
          if (widget.variant == TrainingAmbientVariant.kineticEngine &&
              widget.showKineticImage &&
              !_imageFailed)
            Image(
              key: const ValueKey('kinetic-engine-background-image'),
              image: _imageProvider,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                KineticFirstFrameInstrumentation.imageError(error);
                return const SizedBox.expand();
              },
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (frame != null || wasSynchronouslyLoaded) {
                  KineticFirstFrameInstrumentation.firstFrameAfterImageReady();
                }
                return child;
              },
            ),
          CustomPaint(
            key: const ValueKey('kinetic-engine-mechanical-painter'),
            painter: _TrainingAmbientPainter(
              variant: widget.variant,
              time: widget.debugTime ?? _machineClock.elapsedSeconds,
              onFirstKineticPaint:
                  widget.variant == TrainingAmbientVariant.kineticEngine
                  ? KineticFirstFrameInstrumentation.firstKineticPaint
                  : null,
            ),
            child: const SizedBox.expand(),
          ),
        ],
      ),
    ),
  );
}

class TrainingAmbientComparisonSelector extends StatelessWidget {
  const TrainingAmbientComparisonSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final TrainingAmbientVariant selected;
  final ValueChanged<TrainingAmbientVariant> onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xdd07121d),
      border: Border.all(color: const Color(0x664db8ff)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.all(5),
      child: Wrap(
        spacing: 4,
        children: [
          for (final value in TrainingAmbientVariant.values)
            Semantics(
              selected: value == selected,
              child: ActionableFeedbackRegion(
                role: ActionableFeedbackRole.silent,
                child: ChoiceChip(
                  key: ValueKey('training-ambient-${value.name}'),
                  label: Text(value.label),
                  selected: value == selected,
                  onSelected: (_) {
                    if (value == selected) return;
                    GlobalTouchRipple.previewFeedback(
                      TouchFeedbackSound.cursor,
                    );
                    onChanged(value);
                  },
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// One-shot startup diagnostics. They compile out of release behavior and are
/// deliberately observational: Flutter frame timings are not GPU presentation
/// measurements, especially on iPhone Safari.
class KineticFirstFrameInstrumentation {
  KineticFirstFrameInstrumentation._();

  static final Map<String, Duration> _marks = <String, Duration>{};
  static final List<FrameTiming> _frameTimings = <FrameTiming>[];
  static Stopwatch? _clock;
  static bool _collecting = false;

  static bool get _enabled => kDebugMode || kProfileMode;
  static Map<String, Duration> get marks => Map.unmodifiable(_marks);
  static List<FrameTiming> get frameTimings => List.unmodifiable(_frameTimings);

  static void routeInit() => _startIfNeeded();
  static void ambientInit() {
    _startIfNeeded();
    _mark('t_routeInit');
  }

  static void firstScaffoldBuild() => _mark('t_firstScaffoldBuild');
  static void imageResolveStart() => _mark('t_imageResolveStart');
  static void imageReady() => _mark('t_imageReady');
  static void imageError(Object error) => _mark('t_imageError');
  static void firstFallbackPaint() => _mark('t_firstFallbackPaint');
  static void firstKineticPaint() => _mark('t_firstKineticPaint');
  static void firstFrameAfterImageReady() =>
      _mark('t_firstFrameAfterImageReady');

  static void _startIfNeeded() {
    if (!_enabled || _collecting) return;
    _collecting = true;
    _marks.clear();
    _frameTimings.clear();
    _clock = Stopwatch()..start();
    _mark('t_routeInit');
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static void _onTimings(List<FrameTiming> timings) {
    if (!_enabled || _frameTimings.length >= 30) return;
    _frameTimings.addAll(timings.take(30 - _frameTimings.length));
  }

  static void _mark(String name) {
    if (!_enabled || _marks.containsKey(name)) return;
    _marks[name] = _clock?.elapsed ?? Duration.zero;
  }

  static void dispose() {
    if (!_collecting) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _collecting = false;
  }
}

/// Synchronous, asset-independent base used while the browser resolves WebP.
/// It intentionally reuses only broad engine anchors so it never becomes a
/// second mechanical composition or an asynchronous loading surface.
class _KineticFirstFrameFallbackPainter extends CustomPainter {
  const _KineticFirstFrameFallbackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    KineticFirstFrameInstrumentation.firstFallbackPaint();
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff030914),
    );
    final structural = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xff51d7f4).withValues(alpha: .18);
    final anchors = <(Offset, Offset)>[
      (
        Offset(size.width * .08, size.height * .21),
        Offset(size.width * .39, size.height * .34),
      ),
      (
        Offset(size.width * .39, size.height * .34),
        Offset(size.width * .70, size.height * .18),
      ),
      (
        Offset(size.width * .12, size.height * .73),
        Offset(size.width * .43, size.height * .61),
      ),
      (
        Offset(size.width * .43, size.height * .61),
        Offset(size.width * .84, size.height * .73),
      ),
    ];
    for (final (start, end) in anchors) {
      canvas.drawLine(start, end, structural..strokeWidth = 1.1);
    }
    final hubPaint = Paint()
      ..color = const Color(0xff81e9fb).withValues(alpha: .18);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xff81e9fb).withValues(alpha: .22);
    for (final center in [
      Offset(size.width * .39, size.height * .34),
      Offset(size.width * .43, size.height * .61),
    ]) {
      canvas.drawCircle(center, size.shortestSide * .055, hubPaint);
      canvas.drawCircle(center, size.shortestSide * .095, ring);
    }
  }

  @override
  bool shouldRepaint(covariant _KineticFirstFrameFallbackPainter oldDelegate) =>
      false;
}

class _TrainingAmbientPainter extends CustomPainter {
  const _TrainingAmbientPainter({
    required this.variant,
    required this.time,
    this.onFirstKineticPaint,
  });
  final TrainingAmbientVariant variant;
  final double time;
  final VoidCallback? onFirstKineticPaint;

  @override
  void paint(Canvas canvas, Size size) {
    switch (variant) {
      case TrainingAmbientVariant.magneticFlux:
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = const Color(0xff030914),
        );
        _flux(canvas, size);
      case TrainingAmbientVariant.kineticEngine:
        onFirstKineticPaint?.call();
        _engine(canvas, size);
      case TrainingAmbientVariant.vectorImpulse:
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = const Color(0xff030914),
        );
        _vectors(canvas, size);
    }
  }

  void _flux(Canvas canvas, Size size) {
    final centers = [
      Offset(
        size.width * (.24 + .07 * math.sin(time * .19)),
        size.height * (.27 + .08 * math.cos(time * .14)),
      ),
      Offset(
        size.width * (.73 + .06 * math.cos(time * .17 + 1)),
        size.height * (.46 + .10 * math.sin(time * .13 + .6)),
      ),
      Offset(
        size.width * (.47 + .09 * math.sin(time * .11 + 2)),
        size.height * (.77 + .05 * math.cos(time * .21)),
      ),
    ];
    const polarities = [1.0, -1.0, .72];
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 36; i++) {
      final source =
          centers[i % centers.length] +
          Offset.fromDirection(
            i * math.pi * 2 / 12 + time * (.025 + (i % 3) * .006),
            12 + (i % 6) * 4,
          );
      final points = _integrateField(
        source,
        centers,
        polarities,
        size,
        i.isEven ? 1 : -1,
      );
      if (points.length < 3) continue;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      final middle = points[points.length ~/ 2];
      final concentration = _fieldAt(middle, centers, polarities).distance;
      final intensity = (concentration / 20).clamp(.18, 1.0);
      stroke
        ..color = Color.lerp(
          const Color(0x334be9ff),
          const Color(0x775c5cff),
          (i % 18) / 18,
        )!
        ..color = stroke.color.withValues(alpha: .18 + intensity * .42)
        ..strokeWidth = i % 6 == 0 ? 1.55 : .52 + intensity * .48;
      canvas.drawPath(path, stroke);
      if (i % 3 == 0) {
        final u = (time * (.12 + (i % 5) * .012) + i * .09) % 1;
        final pointIndex = (u * (points.length - 1)).floor();
        final point = points[pointIndex];
        final next = points[math.min(pointIndex + 1, points.length - 1)];
        final tangent = next - point;
        canvas.drawLine(
          point - tangent * .8,
          point + tangent * .8,
          Paint()
            ..strokeWidth = 1.1
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xaa8cf5ff),
        );
        canvas.drawCircle(
          point,
          2.2,
          Paint()
            ..color = const Color(0xff8cf5ff)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }
    for (var i = 0; i < centers.length; i++) {
      final c = centers[i];
      canvas.drawCircle(
        c,
        26 + math.sin(time * .7 + i) * 5,
        Paint()
          ..color = const Color(0x224fddff)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
      canvas.drawCircle(c, 4.5, Paint()..color = const Color(0xffb7faff));
    }
  }

  void _engine(Canvas canvas, Size size) {
    final gears = TrainingAmbientComparison.kineticGearGeometryFor(size);
    final backgroundGears =
        TrainingAmbientComparison.kineticBackgroundGearGeometryFor(size);
    final byId = {for (final gear in gears) gear.id: gear};
    final drivePhase = TrainingAmbientComparison.kineticDrivePhase(time);

    // The independent lower layer is deliberately painted before the V6.2
    // transmission so its subdued gear groups create depth without competing
    // with the established primary train.
    final backgroundById = {for (final gear in backgroundGears) gear.id: gear};
    for (final gear in backgroundGears) {
      final parentId = gear.parentId;
      if (parentId == null) continue;
      final parent = backgroundById[parentId]!;
      canvas.drawLine(
        parent.center,
        gear.center,
        Paint()
          ..strokeWidth = gear.module * 2.3
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x552e75a8),
      );
    }
    for (var i = 0; i < backgroundGears.length; i++) {
      final gear = backgroundGears[i];
      _gear(canvas, gear, gear.phaseAt(drivePhase), i, background: true);
    }

    for (final gear in gears) {
      final parentId = gear.parentId;
      if (parentId == null) continue;
      final parent = byId[parentId]!;
      canvas.drawLine(
        parent.center,
        gear.center,
        Paint()
          ..strokeWidth = gear.module * 2.8
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x886bd6ff),
      );
    }
    for (var i = 0; i < gears.length; i++) {
      _gear(canvas, gears[i], gears[i].phaseAt(drivePhase), i);
    }
    // Fixed supports are painted before the moving members.  This gives the
    // RECORD rocker root and REPORT SYNC axles a visible machine-frame
    // attachment without constraining the existing animation geometry.
    _reportSyncSupports(canvas, byId['mid-crown']!);
    _reportSyncCoveredBearingCap(canvas, byId['mid-crown']!);
    _recordRockerRootSupport(canvas, byId['right-crown']!);
    _steamLinkage(canvas, byId['mid-crown']!, drivePhase);
    _rockerLinkage(canvas, byId['right-crown']!, drivePhase);
    final output = byId['output-crown']!;
    final outputAngle = output.phaseAt(drivePhase);
    final crankPin =
        output.center +
        Offset.fromDirection(outputAngle, output.pitchRadius * .62);
    final sliderY = output.center.dy + output.module * 38;
    final rod = output.module * 48;
    final vertical = sliderY - crankPin.dy;
    final sliderX =
        crankPin.dx + math.sqrt(math.max(0, rod * rod - vertical * vertical));
    final slider = Offset(sliderX, sliderY);
    canvas.drawLine(
      Offset(0, sliderY),
      Offset(size.width, sliderY),
      Paint()
        ..strokeWidth = output.module * 5.4
        ..color = const Color(0xff192633),
    );
    canvas.drawLine(
      crankPin,
      slider,
      Paint()
        ..strokeWidth = output.module * 4.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xff60798a),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: slider,
          width: output.module * 29,
          height: output.module * 11,
        ),
        Radius.circular(output.module * 2),
      ),
      Paint()..color = const Color(0xff344857),
    );
    canvas.drawCircle(
      crankPin,
      output.module * 2,
      Paint()..color = const Color(0xff80dcf5),
    );
    _mechanicalCovers(canvas, size);
  }

  void _reportSyncCoveredBearingCap(
    Canvas canvas,
    KineticGearGeometry driveGear,
  ) {
    final left = TrainingAmbientComparison.kineticReportSyncSupportGeometryFor(
      driveGear,
    ).first;
    _fixedBearingHousing(
      canvas,
      left.anchor,
      scale: driveGear.module,
      radius: 6.4,
    );
    _supportBolt(
      canvas,
      left.anchor + Offset(driveGear.module * 9, driveGear.module * 3.8),
      driveGear.module * 1.55,
    );
  }

  void _mechanicalCovers(Canvas canvas, Size size) {
    final covers = TrainingAmbientComparison.kineticMechanicalCoversFor(size);
    final right = covers[0];
    final lower = covers[1];
    final platePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xee35566c), Color(0xee172d42), Color(0xee0c1c2d)],
        stops: [0, .55, 1],
      ).createShader(Offset.zero & size);
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = const Color(0xb66fd7ed);
    final recessPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..color = const Color(0x99102135);
    final clearPaint = Paint()..blendMode = BlendMode.clear;

    final rightPath = Path()
      ..moveTo(right.bounds.right, right.bounds.top)
      ..lineTo(right.bounds.left + right.bounds.width * .20, right.bounds.top)
      ..lineTo(right.bounds.left, right.bounds.top + right.bounds.height * .16)
      ..lineTo(
        right.bounds.left + right.bounds.width * .12,
        right.bounds.top + right.bounds.height * .34,
      )
      ..lineTo(
        right.bounds.left + right.bounds.width * .03,
        right.bounds.top + right.bounds.height * .53,
      )
      ..lineTo(
        right.bounds.left + right.bounds.width * .31,
        right.bounds.top + right.bounds.height * .82,
      )
      ..lineTo(
        right.bounds.left + right.bounds.width * .54,
        right.bounds.top + right.bounds.height * .73,
      )
      ..lineTo(
        right.bounds.left + right.bounds.width * .76,
        right.bounds.bottom,
      )
      ..lineTo(right.bounds.right, right.bounds.bottom * .94)
      ..close();
    canvas.drawShadow(rightPath, const Color(0xdd000713), 8, false);
    canvas.saveLayer(right.bounds.inflate(10), Paint());
    canvas.drawPath(rightPath, platePaint);
    final rightRoundOpening = Rect.fromCenter(
      center: Offset(
        right.bounds.left + right.bounds.width * .47,
        right.bounds.top + right.bounds.height * .32,
      ),
      width: right.bounds.width * .22,
      height: right.bounds.height * .18,
    );
    final rightSlot = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(
          right.bounds.left + right.bounds.width * .60,
          right.bounds.top + right.bounds.height * .63,
        ),
        width: right.bounds.width * .35,
        height: right.bounds.height * .105,
      ),
      Radius.circular(right.bounds.height * .05),
    );
    canvas.drawOval(rightRoundOpening, clearPaint);
    canvas.drawRRect(rightSlot, clearPaint);
    canvas.drawPath(rightPath, edgePaint);
    canvas.drawOval(rightRoundOpening, recessPaint);
    canvas.drawRRect(rightSlot, recessPaint);
    canvas.restore();
    _coverRib(
      canvas,
      Offset(right.bounds.left + right.bounds.width * .19, right.bounds.top),
      Offset(
        right.bounds.left + right.bounds.width * .43,
        right.bounds.top + right.bounds.height * .75,
      ),
      5.5,
    );
    for (final mount in right.mounts) {
      _coverMount(canvas, mount, size.width * .023);
    }

    final lowerPath = Path()
      ..moveTo(lower.bounds.left, lower.bounds.top + lower.bounds.height * .08)
      ..cubicTo(
        lower.bounds.left + lower.bounds.width * .22,
        lower.bounds.top,
        lower.bounds.left + lower.bounds.width * .62,
        lower.bounds.top + lower.bounds.height * .12,
        lower.bounds.left + lower.bounds.width * .83,
        lower.bounds.top + lower.bounds.height * .35,
      )
      ..quadraticBezierTo(
        lower.bounds.right,
        lower.bounds.top + lower.bounds.height * .56,
        lower.bounds.left + lower.bounds.width * .72,
        lower.bounds.top + lower.bounds.height * .69,
      )
      ..lineTo(
        lower.bounds.left + lower.bounds.width * .93,
        lower.bounds.bottom,
      )
      ..lineTo(lower.bounds.left, lower.bounds.bottom)
      ..close();
    canvas.drawShadow(lowerPath, const Color(0xdd000713), 9, false);
    canvas.saveLayer(lower.bounds.inflate(10), Paint());
    canvas.drawPath(lowerPath, platePaint);
    final lowerArcOpening = Rect.fromCenter(
      center: Offset(
        lower.bounds.left + lower.bounds.width * .30,
        lower.bounds.top + lower.bounds.height * .42,
      ),
      width: lower.bounds.width * .29,
      height: lower.bounds.width * .29,
    );
    final lowerSlot = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(
          lower.bounds.left + lower.bounds.width * .62,
          lower.bounds.top + lower.bounds.height * .50,
        ),
        width: lower.bounds.width * .28,
        height: lower.bounds.height * .09,
      ),
      Radius.circular(lower.bounds.height * .045),
    );
    final lowerSmallOpening = Rect.fromCenter(
      center: Offset(
        lower.bounds.left + lower.bounds.width * .18,
        lower.bounds.top + lower.bounds.height * .73,
      ),
      width: lower.bounds.width * .13,
      height: lower.bounds.width * .13,
    );
    canvas.drawOval(lowerArcOpening, clearPaint);
    canvas.drawRRect(lowerSlot, clearPaint);
    canvas.drawOval(lowerSmallOpening, clearPaint);
    canvas.drawPath(lowerPath, edgePaint);
    canvas.drawOval(lowerArcOpening, recessPaint);
    canvas.drawRRect(lowerSlot, recessPaint);
    canvas.drawOval(lowerSmallOpening, recessPaint);
    canvas.restore();
    _coverRib(
      canvas,
      Offset(lower.bounds.left, lower.bounds.top + lower.bounds.height * .18),
      Offset(
        lower.bounds.left + lower.bounds.width * .76,
        lower.bounds.top + lower.bounds.height * .62,
      ),
      6,
    );
    for (final mount in lower.mounts) {
      _coverMount(canvas, mount, size.width * .023);
    }
  }

  void _coverRib(Canvas canvas, Offset start, Offset end, double width) {
    canvas.drawLine(
      start,
      end,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width
        ..color = const Color(0xaa132b40),
    );
    canvas.drawLine(
      start.translate(0, -1),
      end.translate(0, -1),
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1
        ..color = const Color(0x885cbbd4),
    );
  }

  void _coverMount(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius * 1.42,
      Paint()..color = const Color(0xff10283b),
    );
    canvas.drawCircle(
      center,
      radius * 1.42,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xaa6ad3e9),
    );
    canvas.drawCircle(
      center,
      radius * .68,
      Paint()..color = const Color(0xff58798c),
    );
    canvas.drawLine(
      center + Offset(-radius * .42, 0),
      center + Offset(radius * .42, 0),
      Paint()
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xff0a1a29),
    );
  }

  void _recordRockerRootSupport(Canvas canvas, KineticGearGeometry driveGear) {
    final support = TrainingAmbientComparison.kineticRecordRootSupportFor(
      driveGear,
    );
    final scale = driveGear.module;
    _fixedSupportPlate(
      canvas,
      support,
      scale: scale,
      width: scale * 24,
      height: scale * 20,
      direction: -1,
    );
    // The outer race belongs to the static bracket.  The rocker’s inner
    // bearing is painted later by _rockerLinkage and remains free to rotate.
    _fixedBearingHousing(canvas, support.anchor, scale: scale, radius: 7.4);
    _supportRib(
      canvas,
      support.anchor + Offset(-scale * 10.5, scale * 8.6),
      support.anchor + Offset(-scale * 17, scale * 15.5),
      scale,
    );
  }

  void _reportSyncSupports(Canvas canvas, KineticGearGeometry driveGear) {
    final supports =
        TrainingAmbientComparison.kineticReportSyncSupportGeometryFor(
          driveGear,
        );
    final scale = driveGear.module;
    for (var i = 0; i < supports.length; i++) {
      _fixedSupportPlate(
        canvas,
        supports[i],
        scale: scale,
        width: scale * (i == 1 ? 21 : 18),
        height: scale * 16,
        direction: i == 0 ? -1 : 1,
      );
      _fixedBearingHousing(
        canvas,
        supports[i].anchor,
        scale: scale,
        radius: i == 1 ? 6.9 : 6.4,
      );
    }
  }

  void _fixedSupportPlate(
    Canvas canvas,
    KineticLinkageSupportGeometry support, {
    required double scale,
    required double width,
    required double height,
    required double direction,
  }) {
    final anchor = support.anchor;
    final left = anchor.dx - width * .5;
    final right = anchor.dx + width * .5;
    final top = anchor.dy - height * .42;
    final bottom = anchor.dy + height * .70;
    final plate = Path()
      ..moveTo(left, bottom)
      ..lineTo(left + width * .10, top + height * .22)
      ..lineTo(anchor.dx - width * .12, top)
      ..lineTo(right - width * .08, top + height * .16)
      ..lineTo(right, bottom - height * .23)
      ..lineTo(anchor.dx + direction * width * .24, bottom)
      ..lineTo(left + width * .13, bottom)
      ..close();
    final bounds = Rect.fromLTRB(left, top, right, bottom);
    canvas.saveLayer(bounds.inflate(scale * 2), Paint());
    canvas.drawPath(
      plate,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            Color(0xee365d75),
            Color(0xee19384f),
            Color(0xee0d2032),
          ],
        ).createShader(bounds),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: anchor + Offset(direction * width * .13, height * .23),
          width: width * .23,
          height: height * .15,
        ),
        Radius.circular(height * .08),
      ),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
    canvas.drawPath(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, scale * .78)
        ..color = const Color(0xff76d9ed),
    );
    canvas.drawLine(
      Offset(left + width * .14, bottom - height * .13),
      Offset(right - width * .16, bottom - height * .30),
      Paint()
        ..strokeWidth = math.max(1, scale * 1.05)
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xaa0d2032),
    );
    for (final mount in support.mounts) {
      _supportBolt(canvas, mount, scale * 2.15);
    }
  }

  void _fixedBearingHousing(
    Canvas canvas,
    Offset center, {
    required double scale,
    required double radius,
  }) {
    canvas.drawCircle(
      center,
      scale * radius,
      Paint()..color = const Color(0xff102b40),
    );
    canvas.drawCircle(
      center,
      scale * radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, scale * .9)
        ..color = const Color(0xff74d8ee),
    );
    canvas.drawCircle(
      center,
      scale * radius * .68,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.8, scale * .75)
        ..color = const Color(0xff355f78),
    );
  }

  void _supportBolt(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xff0b1b2b));
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9
        ..color = const Color(0xff7194a6),
    );
    canvas.drawLine(
      center + Offset(-radius * .42, 0),
      center + Offset(radius * .42, 0),
      Paint()
        ..strokeWidth = .9
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xff9fc6d4),
    );
  }

  void _supportRib(Canvas canvas, Offset start, Offset end, double scale) {
    canvas.drawLine(
      start,
      end,
      Paint()
        ..strokeWidth = scale * 3.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xff173a52),
    );
    canvas.drawLine(
      start.translate(0, -scale * .5),
      end.translate(0, -scale * .5),
      Paint()
        ..strokeWidth = math.max(.8, scale * .62)
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xff75d9ec),
    );
  }

  void _steamLinkage(
    Canvas canvas,
    KineticGearGeometry driveGear,
    double drivePhase,
  ) {
    final pose = TrainingAmbientComparison.kineticSteamLinkagePoseFor(
      driveGear,
      drivePhase,
    );
    final transmission =
        TrainingAmbientComparison.kineticReportSyncTransmissionPoseFor(
          driveGear,
          drivePhase,
        );
    final scale = driveGear.module;
    // Fixed support plates and bearing outer races are already behind this
    // block. Pulley bodies sit above them, then each constant-length belt is
    // visible over its wrapped arcs before the front pulley faces and rods.
    for (var i = 0; i < transmission.axleCenters.length; i++) {
      _reportSyncPulleyBase(
        canvas,
        transmission.axleCenters[i],
        radius: transmission.pulleyRadius,
        driveFlange: i == transmission.axleCenters.length - 1,
      );
    }
    for (var i = 0; i < transmission.axleCenters.length - 1; i++) {
      _openBelt(
        canvas,
        transmission.axleCenters[i],
        transmission.axleCenters[i + 1],
        radius: transmission.pulleyRadius,
        phase: transmission.phase + i * .31,
      );
    }
    for (var i = 0; i < transmission.axleCenters.length; i++) {
      _reportSyncPulleyFront(
        canvas,
        transmission.axleCenters[i],
        scale: scale,
        radius: transmission.pulleyRadius,
        phase: transmission.phase,
        dualGroove: i == 1,
        driveFlange: i == transmission.axleCenters.length - 1,
      );
    }
    final railPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = scale * 2.4
      ..color = const Color(0xc6386078);
    canvas.drawLine(
      pose.guideStart + Offset(0, -scale * 5.2),
      pose.guideEnd + Offset(0, -scale * 5.2),
      railPaint,
    );
    canvas.drawLine(
      pose.guideStart + Offset(0, scale * 5.2),
      pose.guideEnd + Offset(0, scale * 5.2),
      railPaint,
    );

    // The three equal cranks keep the rigid coupling rod mechanically exact.
    // A separate drive rod creates the visible SL-style angular swing and
    // reciprocating crosshead travel without stretching either connection.
    for (var i = 0; i < pose.crankPins.length - 1; i++) {
      _mechanicalRod(
        canvas,
        pose.crankPins[i],
        pose.crankPins[i + 1],
        scale: scale,
        bodyWidth: 7.4,
        endRadius: 5.2,
        bodyColor: const Color(0xff456f87),
      );
    }
    _mechanicalRod(
      canvas,
      pose.crankPins.last,
      pose.crosshead,
      scale: scale,
      bodyWidth: 8.6,
      endRadius: 5.8,
      bodyColor: const Color(0xff527f96),
    );

    for (var i = 0; i < pose.axleCenters.length; i++) {
      final center = pose.axleCenters[i];
      final pin = pose.crankPins[i];
      _mechanicalRod(
        canvas,
        center,
        pin,
        scale: scale,
        bodyWidth: 4.7,
        endRadius: 3.6,
        bodyColor: const Color(0xff315b73),
      );
      // The static outer bearing race was painted with the supports. This
      // compact inner axle cap remains in front with the rotating crank.
      _bearingJoint(
        canvas,
        center,
        scale: scale,
        radius: 3.85,
        coreRadius: 1.7,
      );
      _bearingJoint(canvas, pin, scale: scale, radius: 5, coreRadius: 2);
    }

    final crossheadRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: pose.crosshead,
        width: scale * 15.5,
        height: scale * 14,
      ),
      Radius.circular(scale * 3),
    );
    canvas.drawRRect(crossheadRect, Paint()..color = const Color(0xff19384f));
    canvas.drawRRect(
      crossheadRect.deflate(scale * 1.25),
      Paint()..color = const Color(0xff426c83),
    );
    canvas.drawRRect(
      crossheadRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * .9
        ..color = const Color(0xff8cecff),
    );
    _bearingJoint(
      canvas,
      pose.crosshead,
      scale: scale,
      radius: 4.5,
      coreRadius: 1.65,
    );
  }

  void _openBelt(
    Canvas canvas,
    Offset start,
    Offset end, {
    required double radius,
    required double phase,
  }) {
    final loop = _OpenBeltLoop(start, end, radius);
    if (!loop.isValid) return;
    final path = loop.path;
    final beltWidth = math.max(4.2, radius * .62);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = beltWidth + 1.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xff071926),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = beltWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xff28556b),
    );
    // A darker center channel and two restrained edge highlights give the
    // belt depth without turning the moving detail into floating diagonals.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.75, beltWidth * .18)
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xff092536),
    );
    canvas.drawPath(
      loop.edgePath(beltWidth * .38),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.55, beltWidth * .10)
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xff6a9cb0),
    );
    canvas.drawPath(
      loop.edgePath(-beltWidth * .38),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.55, beltWidth * .10)
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xff0c2b3e),
    );

    final ribSpacing = math.max(7.2, radius * 1.12);
    final ribOffset = (phase * radius) % ribSpacing;
    for (
      var distance = ribOffset;
      distance < loop.loopLength + ribSpacing;
      distance += ribSpacing
    ) {
      final sample = loop.sampleAt(distance);
      final normal = Offset(-sample.tangent.dy, sample.tangent.dx);
      final halfWidth = beltWidth * .33;
      canvas.drawLine(
        sample.position - normal * halfWidth,
        sample.position + normal * halfWidth,
        Paint()
          ..strokeWidth = math.max(.55, beltWidth * .11)
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xff90c9db),
      );
    }
  }

  void _reportSyncPulleyBase(
    Canvas canvas,
    Offset center, {
    required double radius,
    required bool driveFlange,
  }) {
    final fill = driveFlange
        ? const Color(0xff315e78)
        : const Color(0xff24485f);
    canvas.drawCircle(center, radius, Paint()..color = fill);
    canvas.drawCircle(
      center,
      radius * .78,
      Paint()..color = const Color(0xff17384f),
    );
  }

  void _reportSyncPulleyFront(
    Canvas canvas,
    Offset center, {
    required double scale,
    required double radius,
    required double phase,
    required bool dualGroove,
    required bool driveFlange,
  }) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, scale * .85)
        ..color = const Color(0xff83e6fa),
    );
    if (dualGroove) {
      canvas.drawCircle(
        center,
        radius * .76,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.15, scale * .94)
          ..color = const Color(0xff102b40),
      );
      canvas.drawCircle(
        center,
        radius * .57,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(.9, scale * .7)
          ..color = const Color(0xff5b879d),
      );
    }
    for (var i = 0; i < 4; i++) {
      final angle = phase + i * math.pi / 2;
      canvas.drawLine(
        center + Offset.fromDirection(angle, radius * .24),
        center + Offset.fromDirection(angle, radius * .72),
        Paint()
          ..strokeWidth = math.max(.9, scale * .8)
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xff75a8bd),
      );
    }
  }

  void _rockerLinkage(
    Canvas canvas,
    KineticGearGeometry driveGear,
    double drivePhase,
  ) {
    final pose = TrainingAmbientComparison.kineticRockerLinkagePoseFor(
      driveGear,
      drivePhase,
    );
    final scale = driveGear.module;
    final rockerDirection = pose.rockerJoint - pose.fixedPivot;
    final counterArm =
        pose.fixedPivot -
        rockerDirection / rockerDirection.distance * scale * 16;

    _mechanicalRod(
      canvas,
      pose.crankPin,
      pose.rockerJoint,
      scale: scale,
      bodyWidth: 6.8,
      endRadius: 4.6,
      bodyColor: const Color(0xff4b788f),
    );
    _mechanicalRod(
      canvas,
      counterArm,
      pose.rockerJoint,
      scale: scale,
      bodyWidth: 9,
      endRadius: 5.2,
      bodyColor: const Color(0xff355f78),
    );
    _bearingJoint(
      canvas,
      pose.crankPin,
      scale: scale,
      radius: 4.5,
      coreRadius: 1.7,
    );
    _bearingJoint(
      canvas,
      pose.rockerJoint,
      scale: scale,
      radius: 5,
      coreRadius: 1.85,
    );
    _bearingJoint(
      canvas,
      pose.fixedPivot,
      scale: scale,
      radius: 5.5,
      coreRadius: 2,
      fixed: true,
    );
    _bearingJoint(
      canvas,
      counterArm,
      scale: scale,
      radius: 3.8,
      coreRadius: 1.35,
    );
  }

  void _mechanicalRod(
    Canvas canvas,
    Offset start,
    Offset end, {
    required double scale,
    required double bodyWidth,
    required double endRadius,
    required Color bodyColor,
  }) {
    final delta = end - start;
    final length = delta.distance;
    if (length <= .0001) return;
    final direction = delta / length;
    final normal = Offset(-direction.dy, direction.dx);
    final waist = scale * bodyWidth * .5;
    final shoulder = scale * bodyWidth * .72;
    final endR = math.min(scale * endRadius, length * .22);
    final shoulderInset = math.min(endR * 1.3, length * .24);
    final startShoulder = start + direction * shoulderInset;
    final endShoulder = end - direction * shoulderInset;
    final path = Path()
      ..moveTo(start.dx + normal.dx * endR, start.dy + normal.dy * endR)
      ..quadraticBezierTo(
        startShoulder.dx + normal.dx * shoulder,
        startShoulder.dy + normal.dy * shoulder,
        startShoulder.dx + normal.dx * waist,
        startShoulder.dy + normal.dy * waist,
      )
      ..lineTo(
        endShoulder.dx + normal.dx * waist,
        endShoulder.dy + normal.dy * waist,
      )
      ..quadraticBezierTo(
        endShoulder.dx + normal.dx * shoulder,
        endShoulder.dy + normal.dy * shoulder,
        end.dx + normal.dx * endR,
        end.dy + normal.dy * endR,
      )
      ..arcToPoint(
        end - normal * endR,
        radius: Radius.circular(endR),
        clockwise: true,
      )
      ..quadraticBezierTo(
        endShoulder.dx - normal.dx * shoulder,
        endShoulder.dy - normal.dy * shoulder,
        endShoulder.dx - normal.dx * waist,
        endShoulder.dy - normal.dy * waist,
      )
      ..lineTo(
        startShoulder.dx - normal.dx * waist,
        startShoulder.dy - normal.dy * waist,
      )
      ..quadraticBezierTo(
        startShoulder.dx - normal.dx * shoulder,
        startShoulder.dy - normal.dy * shoulder,
        start.dx - normal.dx * endR,
        start.dy - normal.dy * endR,
      )
      ..arcToPoint(
        start + normal * endR,
        radius: Radius.circular(endR),
        clockwise: true,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = bodyColor);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * 1.05
        ..color = const Color(0xff83e6fa),
    );

    final innerStart = start + direction * (endR * 1.45);
    final innerEnd = end - direction * (endR * 1.45);
    if ((innerEnd - innerStart).distance > scale * 4) {
      canvas.drawLine(
        innerStart,
        innerEnd,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = scale * bodyWidth * .34
          ..color = const Color(0xff17384f),
      );
      canvas.drawLine(
        innerStart - normal * scale * .42,
        innerEnd - normal * scale * .42,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = scale * .52
          ..color = const Color(0xff6ea4b9),
      );
    }
  }

  void _bearingJoint(
    Canvas canvas,
    Offset center, {
    required double scale,
    required double radius,
    required double coreRadius,
    bool fixed = false,
  }) {
    canvas.drawCircle(
      center,
      scale * radius,
      Paint()
        ..color = fixed ? const Color(0xff142f45) : const Color(0xff244b64),
    );
    canvas.drawCircle(
      center,
      scale * radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * .92
        ..color = const Color(0xff83e6fa),
    );
    canvas.drawCircle(
      center,
      scale * (radius * .6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * .72
        ..color = const Color(0xff456f87),
    );
    canvas.drawCircle(
      center,
      scale * coreRadius,
      Paint()..color = const Color(0xffb5f4ff),
    );
  }

  void _gear(
    Canvas canvas,
    KineticGearGeometry gear,
    double angle,
    int index, {
    bool background = false,
  }) {
    final profile = _toothProfile(
      gear.center,
      gear.toothCount,
      gear.rootRadius,
      gear.tipRadius,
      angle,
    );
    final variant = TrainingAmbientComparison.kineticGearVisualVariantFor(
      gear,
      index,
      background: background,
    );
    // One material family now spans teeth, rim, spokes and hub mounting. The
    // rear layer uses the same steel-blue material at lower contrast.
    final material = background
        ? const Color(0x8a284b68)
        : const Color(0xe1287598);
    final edge = background ? const Color(0x7a6096b5) : const Color(0xe077dff4);
    final shade = background
        ? const Color(0x5c10243b)
        : const Color(0x9a123c59);
    final layerBounds = Rect.fromCircle(
      center: gear.center,
      radius: gear.tipRadius + 5,
    );
    canvas.saveLayer(layerBounds, Paint());
    canvas.drawPath(profile, Paint()..color = material);
    canvas.drawPath(
      profile.shift(const Offset(1.5, 2.2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.3
        ..color = background
            ? const Color(0x44010a1f)
            : const Color(0x99030a24),
    );
    canvas.drawPath(
      profile,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = background ? .75 : 1.35
        ..color = edge,
    );
    _gearInterior(
      canvas,
      gear,
      angle,
      index,
      variant,
      material: material,
      edge: edge,
      shade: shade,
      background: background,
    );
    canvas.restore();
    if (background) {
      canvas.drawCircle(
        gear.center,
        gear.pitchRadius * .12,
        Paint()..color = const Color(0x886aa4c8),
      );
    } else {
      _luminousHub(canvas, gear);
    }
  }

  void _luminousHub(Canvas canvas, KineticGearGeometry gear) {
    final state = TrainingAmbientComparison.kineticHubGlowStateFor(
      gear.id,
      time,
    );
    final color = state.color;
    final outerRadius = gear.pitchRadius * .31;
    final innerRadius = gear.pitchRadius * .205;
    final coreRadius = gear.pitchRadius * .115;
    final outerBounds = Rect.fromCircle(
      center: gear.center,
      radius: outerRadius,
    );
    final innerBounds = Rect.fromCircle(
      center: gear.center,
      radius: innerRadius,
    );
    final coreBounds = Rect.fromCircle(center: gear.center, radius: coreRadius);
    canvas.drawCircle(
      gear.center,
      outerRadius,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: .28),
            color.withValues(alpha: .10),
            color.withValues(alpha: 0),
          ],
          stops: const [0, .48, 1],
        ).createShader(outerBounds)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(2.2, gear.module * 2.4),
        ),
    );
    canvas.drawCircle(
      gear.center,
      innerRadius,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            Color.lerp(color, Colors.white, .30)!.withValues(alpha: .90),
            color.withValues(alpha: .62),
            color.withValues(alpha: 0),
          ],
          stops: const [0, .46, 1],
        ).createShader(innerBounds)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(1.2, gear.module * 1.15),
        ),
    );
    canvas.drawCircle(
      gear.center,
      coreRadius,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            Color.lerp(color, Colors.white, .68)!.withValues(alpha: .98),
            color.withValues(alpha: .78),
            color.withValues(alpha: 0),
          ],
          stops: const [0, .55, 1],
        ).createShader(coreBounds),
    );
    canvas.drawCircle(
      gear.center,
      gear.pitchRadius * .235,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.7, gear.module * .46)
        ..color = color.withValues(alpha: .18),
    );
  }

  Path _toothProfile(
    Offset center,
    int teeth,
    double rootRadius,
    double tipRadius,
    double angle,
  ) {
    final profile = Path();
    for (var tooth = 0; tooth < teeth; tooth++) {
      final base = angle + tooth * math.pi * 2 / teeth;
      // V11 used a .49 pitch-wide tip with a shallow 2.30-module radial
      // envelope. V11.1 narrows the tip to .33 pitch and deepens the valleys,
      // leaving a recognisable root gap between every adjacent tooth.
      for (final (fraction, radius) in [
        (-.50, rootRadius),
        (-.34, rootRadius),
        (-.18, tipRadius),
        (.15, tipRadius),
        (.30, rootRadius),
        (.50, rootRadius),
      ]) {
        final point =
            center +
            Offset.fromDirection(base + fraction * math.pi * 2 / teeth, radius);
        if (tooth == 0 && fraction == -.50) {
          profile.moveTo(point.dx, point.dy);
        } else {
          profile.lineTo(point.dx, point.dy);
        }
      }
    }
    return profile..close();
  }

  void _gearInterior(
    Canvas canvas,
    KineticGearGeometry gear,
    double angle,
    int index,
    KineticGearVisualVariant variant, {
    required Color material,
    required Color edge,
    required Color shade,
    required bool background,
  }) {
    final r = gear.pitchRadius;
    final spokeCount = TrainingAmbientComparison.kineticSpokeCountFor(
      gear,
      index,
    );
    final innerRim = TrainingAmbientComparison.kineticRimInnerRadiusFactorFor(
      variant,
    );
    void outline(double radius, double width, {double alpha = 1}) =>
        canvas.drawCircle(
          gear.center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(.8, r * width)
            ..color = edge.withValues(alpha: edge.a * alpha),
        );
    void wedgeSpoke(double a, double inner, double outer, double spread) {
      final path = Path()
        ..moveTo(
          (gear.center + Offset.fromDirection(a - spread, r * inner)).dx,
          (gear.center + Offset.fromDirection(a - spread, r * inner)).dy,
        )
        ..lineTo(
          (gear.center + Offset.fromDirection(a - spread * .55, r * outer)).dx,
          (gear.center + Offset.fromDirection(a - spread * .55, r * outer)).dy,
        )
        ..lineTo(
          (gear.center + Offset.fromDirection(a + spread * .55, r * outer)).dx,
          (gear.center + Offset.fromDirection(a + spread * .55, r * outer)).dy,
        )
        ..lineTo(
          (gear.center + Offset.fromDirection(a + spread, r * inner)).dx,
          (gear.center + Offset.fromDirection(a + spread, r * inner)).dy,
        )
        ..close();
      canvas.drawPath(path, Paint()..color = material);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(.65, r * .012)
          ..color = edge.withValues(alpha: edge.a * .58),
      );
    }

    final clearPaint = Paint()..blendMode = BlendMode.clear;
    void clearCircle(Offset center, double radius) =>
        canvas.drawCircle(center, radius, clearPaint);
    void clearWell() => clearCircle(gear.center, r * innerRim);
    void hole(double a, double distance, double radius) => clearCircle(
      gear.center + Offset.fromDirection(a, r * distance),
      math.max(1.1, r * radius),
    );
    void hub(double radius) {
      canvas.drawCircle(gear.center, r * radius, Paint()..color = material);
      outline(r * radius, .018, alpha: .72);
    }

    switch (variant) {
      case KineticGearVisualVariant.openSpoke:
        clearWell();
        for (var i = 0; i < 3; i++) {
          wedgeSpoke(angle + i * math.pi * 2 / 3, .16, .87, .102);
        }
        hub(.20);
        outline(r * innerRim, .018, alpha: .78);
      case KineticGearVisualVariant.thinRim:
        clearWell();
        for (var i = 0; i < 4; i++) {
          wedgeSpoke(angle + .25 + i * math.pi / 2, .14, .90, .052);
        }
        hub(.17);
        outline(r * innerRim, .013, alpha: .68);
      case KineticGearVisualVariant.ringShortSpoke:
        clearWell();
        final innerRingRadius = r * .58;
        canvas.drawCircle(
          gear.center,
          innerRingRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2.2, r * .105)
            ..color = material,
        );
        canvas.drawCircle(
          gear.center,
          innerRingRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(.7, r * .014)
            ..color = edge.withValues(alpha: edge.a * .72),
        );
        for (var i = 0; i < 6; i++) {
          wedgeSpoke(angle + i * math.pi / 3, .63, .88, .042);
        }
        hub(.18);
        outline(r * innerRim, .014, alpha: .72);
      case KineticGearVisualVariant.cutoutDisc:
        final holeCount = spokeCount.clamp(4, 6);
        for (var i = 0; i < holeCount; i++) {
          final a = angle + .18 + i * math.pi * 2 / holeCount;
          hole(a, .52, .155);
        }
        hub(.20);
        outline(r * innerRim, .016, alpha: .72);
      case KineticGearVisualVariant.pinion:
        clearWell();
        for (var i = 0; i < 3; i++) {
          wedgeSpoke(angle + i * math.pi * 2 / 3, .18, .79, .12);
        }
        hub(.24);
      case KineticGearVisualVariant.asymmetric:
        final apertureSpecs = <(double, double, double)>[
          (angle + .18, .48, .18),
          (angle + 1.38, .56, .13),
          (angle + 2.72, .46, .17),
          (angle + 4.22, .55, .12),
        ];
        for (final aperture in apertureSpecs) {
          hole(aperture.$1, aperture.$2, aperture.$3);
        }
        wedgeSpoke(angle + 5.28, .18, .85, .07);
        hub(.21);
        outline(r * innerRim, .014, alpha: .62);
    }
    canvas.drawCircle(
      gear.center + Offset(-r * .025, -r * .035),
      r * .105,
      Paint()..color = shade.withValues(alpha: shade.a * .42),
    );
  }

  List<Offset> _integrateField(
    Offset start,
    List<Offset> centers,
    List<double> polarities,
    Size size,
    int direction,
  ) {
    final points = <Offset>[start];
    var point = start;
    for (var step = 0; step < 58; step++) {
      final vector = _fieldAt(point, centers, polarities);
      if (vector.distance < .0001) {
        break;
      }
      point += vector / vector.distance * direction.toDouble() * 7;
      if (point.dx < -30 ||
          point.dx > size.width + 30 ||
          point.dy < -30 ||
          point.dy > size.height + 30) {
        break;
      }
      points.add(point);
    }
    return points;
  }

  Offset _fieldAt(Offset point, List<Offset> centers, List<double> polarities) {
    var vector = Offset.zero;
    for (var i = 0; i < centers.length; i++) {
      final delta = point - centers[i];
      final squared = math.max(180.0, delta.distanceSquared);
      vector +=
          delta / math.pow(squared, 1.35).toDouble() * polarities[i] * 26000;
    }
    return vector;
  }

  void _vectors(Canvas canvas, Size size) {
    for (var i = 0; i < 11; i++) {
      final seed = _h(i + 31);
      final phase = (time * (.13 + seed * .07) + seed) % 1;
      final origin = Offset(
        size.width * (.08 + _h(i + 51) * .84),
        size.height * (.10 + _h(i + 71) * .80),
      );
      final angle = _h(i + 97) * math.pi * 2 + math.sin(time * .2 + i) * .2;
      final length = 60 + _h(i + 119) * 140;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final head = origin + direction * length * phase;
      final alpha = phase < .16 ? phase / .16 : (1 - phase) / .84;
      final streak = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.2 + _h(i + 139) * 2
        ..shader = LinearGradient(
          colors: const [
            Color(0x0087ecff),
            Color(0xdd5ce5ff),
            Color(0x00de5fff),
          ],
        ).createShader(Rect.fromPoints(origin, head));
      canvas.drawLine(
        origin + direction * length * math.max(0, phase - .24),
        head,
        streak,
      );
      canvas.drawCircle(
        head,
        2.5 + alpha * 3,
        Paint()
          ..color = const Color(0xffc6f7ff).withValues(alpha: alpha.clamp(0, 1))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      if (phase > .72) {
        final r = (phase - .72) / .28 * 32;
        canvas.drawArc(
          Rect.fromCircle(center: head, radius: r),
          angle - .85,
          1.7,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(
              0x884f8fff,
            ).withValues(alpha: 1 - (phase - .72) / .28),
        );
      }
    }
  }

  double _h(int value) {
    final x = math.sin(value * 12.9898) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant _TrainingAmbientPainter oldDelegate) =>
      oldDelegate.variant != variant || oldDelegate.time != time;
}
