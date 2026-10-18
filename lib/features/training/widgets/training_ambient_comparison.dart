import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/touch_ripple_audio.dart';
import '../../../core/widgets/global_touch_ripple.dart';

enum TrainingAmbientVariant {
  magneticFlux('MAGNETIC FLUX'),
  kineticEngine('KINETIC ENGINE'),
  vectorImpulse('VECTOR IMPULSE');

  const TrainingAmbientVariant(this.label);
  final String label;
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
  cutoutDisc,
  pinion,
  asymmetric,
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

class TrainingAmbientComparison extends StatefulWidget {
  const TrainingAmbientComparison({super.key, required this.variant});
  final TrainingAmbientVariant variant;

  static const kineticEngineBackgroundAsset =
      'assets/images/training/kinetic_engine_v9_background.png';

  /// V11.1 profile parameters. Pitch circles remain frozen; only the radial
  /// envelope and angular occupancy around each pitch circle change.
  static const v11ToothRootDedendum = .95;
  static const v11ToothTipAddendum = 1.35;
  static const v11ToothTipAngularWidthFraction = .49;
  static const kineticToothRootDedendum = 1.45;
  static const kineticToothTipAddendum = 1.85;
  static const kineticToothTipAngularWidthFraction = .33;

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
    final stableSeed = gear.id.codeUnits.fold<int>(
      index,
      (sum, code) => sum + code,
    );
    final variants = KineticGearVisualVariant.values;
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 48),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            if (widget.variant == TrainingAmbientVariant.kineticEngine)
              Image.asset(
                TrainingAmbientComparison.kineticEngineBackgroundAsset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.medium,
              ),
            CustomPaint(
              painter: _TrainingAmbientPainter(
                variant: widget.variant,
                time: _controller.value * 48,
              ),
              child: const SizedBox.expand(),
            ),
          ],
        ),
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

class _TrainingAmbientPainter extends CustomPainter {
  const _TrainingAmbientPainter({required this.variant, required this.time});
  final TrainingAmbientVariant variant;
  final double time;

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
    // V10 preserves the exact tooth profile while replacing V9's repeated
    // spoke-and-ring interior with stable, visibly different constructions.
    final fill = background ? const Color(0x7412264a) : const Color(0xa5155a93);
    final edge = background
        ? const Color(0x555eabdc)
        : const Color(0xff78e7ff).withValues(alpha: .88);
    final well = background ? const Color(0xb6051230) : const Color(0xe1061e45);
    final rim = background ? const Color(0x664785bb) : const Color(0xff4ecbff);
    final spokeColor = background
        ? const Color(0x553e7bb0)
        : const Color(0xcc348dcc);
    canvas.drawPath(profile, Paint()..color = fill);
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
      well: well,
      rim: rim,
      spokeColor: spokeColor,
      background: background,
    );
    if (!background) {
      canvas.drawCircle(
        gear.center,
        gear.pitchRadius * .22,
        Paint()
          ..color = const Color(0x8844d9ff)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    canvas.drawCircle(
      gear.center,
      gear.pitchRadius * .12,
      Paint()
        ..color = background
            ? const Color(0x886aa4c8)
            : const Color(0xffffa74f),
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
    required Color well,
    required Color rim,
    required Color spokeColor,
    required bool background,
  }) {
    final r = gear.pitchRadius;
    final spokeCount = TrainingAmbientComparison.kineticSpokeCountFor(
      gear,
      index,
    );
    void outline(double radius, double width, {double alpha = 1}) =>
        canvas.drawCircle(
          gear.center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(.8, r * width)
            ..color = rim.withValues(alpha: rim.a * alpha),
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
      canvas.drawPath(path, Paint()..color = spokeColor);
    }

    void hole(double a, double distance, double radius) => canvas.drawCircle(
      gear.center + Offset.fromDirection(a, r * distance),
      math.max(1.1, r * radius),
      Paint()..color = const Color(0xff041127),
    );

    switch (variant) {
      case KineticGearVisualVariant.openSpoke:
        canvas.drawCircle(gear.center, r * .71, Paint()..color = well);
        outline(r * .66, .085);
        for (var i = 0; i < spokeCount; i++) {
          wedgeSpoke(angle + i * math.pi * 2 / spokeCount, .14, .65, .085);
        }
      case KineticGearVisualVariant.thinRim:
        canvas.drawCircle(gear.center, r * .77, Paint()..color = well);
        outline(r * .73, .052);
        for (var i = 0; i < 3; i++) {
          wedgeSpoke(angle + .25 + i * math.pi * 2 / 3, .17, .70, .042);
        }
      case KineticGearVisualVariant.cutoutDisc:
        canvas.drawCircle(gear.center, r * .70, Paint()..color = well);
        for (var i = 0; i < spokeCount; i++) {
          final a = angle + .18 + i * math.pi * 2 / spokeCount;
          hole(a, .45, i.isEven ? .135 : .095);
        }
      case KineticGearVisualVariant.pinion:
        canvas.drawCircle(gear.center, r * .63, Paint()..color = well);
        for (var i = 0; i < 3; i++) {
          wedgeSpoke(angle + i * math.pi * 2 / 3, .12, .58, .11);
        }
      case KineticGearVisualVariant.asymmetric:
        canvas.drawCircle(gear.center, r * .70, Paint()..color = well);
        const offsets = [0.0, .72, 2.12, 3.45, 5.02];
        for (var i = 0; i < offsets.length; i++) {
          final a = angle + offsets[i];
          if (i.isEven) {
            hole(a, .43, .14);
          } else {
            wedgeSpoke(a, .17, .63, .055);
          }
        }
    }
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
