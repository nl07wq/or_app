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
    KineticGearGeometry root(String id, Offset center, int teeth) =>
        KineticGearGeometry(
          id: id,
          center: center,
          toothCount: teeth,
          module: module,
          pitchRadius: module * teeth,
          rootRadius: module * (teeth - .95),
          tipRadius: module * (teeth + 1.35),
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
        rootRadius: module * (teeth - .95),
        tipRadius: module * (teeth + 1.35),
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
      rootRadius: module * (teeth - .95),
      tipRadius: module * (teeth + 1.35),
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
        rootRadius: module * (teeth - .95),
        tipRadius: module * (teeth + 1.35),
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
          Offset(-.08, .00), Offset(.38, -.02), Offset(.56, .16),
          Offset(.47, .31), Offset(.17, .35), Offset(-.04, .22),
        ],
        mountGearIds: ['main-drive', 'upper-left', 'upper-right'],
        bridgeGearIds: [('main-drive', 'upper-left'), ('main-drive', 'upper-right')],
      ),
      const KineticBaseplateGeometry(
        plate: [
          Offset(.56, .08), Offset(1.08, .05), Offset(1.06, .38),
          Offset(.79, .47), Offset(.57, .33),
        ],
        mountGearIds: [
          'background-north-right-drive', 'background-north-right-outer',
          'right-crown',
        ],
        bridgeGearIds: [
          ('background-north-right-drive', 'background-north-right-outer'),
          ('right-crown', 'right-transfer'),
        ],
      ),
      const KineticBaseplateGeometry(
        plate: [
          Offset(-.08, .31), Offset(.34, .28), Offset(.58, .45),
          Offset(.45, .68), Offset(.09, .70), Offset(-.06, .54),
        ],
        mountGearIds: [
          'left-crown', 'mid-drive', 'background-south-left-drive',
        ],
        bridgeGearIds: [
          ('left-crown', 'left-transfer'),
          ('mid-drive', 'mid-crown'),
          ('background-south-left-drive', 'background-south-left-outer'),
        ],
      ),
      const KineticBaseplateGeometry(
        plate: [
          Offset(.52, .48), Offset(1.07, .43), Offset(1.05, .78),
          Offset(.77, .89), Offset(.48, .75),
        ],
        mountGearIds: [
          'output-crown', 'bottom-drive', 'background-south-right-drive',
        ],
        bridgeGearIds: [
          ('output-crown', 'output-pinion'),
          ('bottom-drive', 'bottom-crown'),
          ('background-south-right-drive', 'background-south-right-upper'),
        ],
      ),
      const KineticBaseplateGeometry(
        plate: [
          Offset(-.07, .69), Offset(.44, .66), Offset(.61, .84),
          Offset(.51, 1.05), Offset(.04, 1.04), Offset(-.08, .89),
        ],
        mountGearIds: ['escapement', 'bottom-crown', 'background-south-left-crown'],
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
          .every((bridge) => ids.contains(bridge.$1) && ids.contains(bridge.$2)),
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
        builder: (context, _) => CustomPaint(
          painter: _TrainingAmbientPainter(
            variant: widget.variant,
            time: _controller.value * 48,
          ),
          child: const SizedBox.expand(),
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
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff030914),
    );
    switch (variant) {
      case TrainingAmbientVariant.magneticFlux:
        _flux(canvas, size);
      case TrainingAmbientVariant.kineticEngine:
        _engine(canvas, size);
      case TrainingAmbientVariant.vectorImpulse:
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
    final baseplates = TrainingAmbientComparison.kineticBaseplateGeometryFor(
      size,
      primaryGears: gears,
      backgroundGears: backgroundGears,
    );
    final byId = {for (final gear in gears) gear.id: gear};
    final allGears = {
      for (final gear in [...gears, ...backgroundGears]) gear.id: gear,
    };
    final drivePhase = TrainingAmbientComparison.kineticDrivePhase(time);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x99101924),
    );

    // V8: the motionless baseplate is intentionally rendered first.  Its
    // mounting seats make the V7 pivots read as one watch-like assembly while
    // leaving every gear profile and animation untouched.
    _baseplates(canvas, size, baseplates, allGears);

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
          ..strokeWidth = gear.module * 3.6
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x7a172633),
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
          ..strokeWidth = gear.module * 4.6
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xff263442),
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

  void _baseplates(
    Canvas canvas,
    Size size,
    List<KineticBaseplateGeometry> plates,
    Map<String, KineticGearGeometry> gears,
  ) {
    for (var index = 0; index < plates.length; index++) {
      final plate = plates[index];
      final path = Path();
      for (var pointIndex = 0; pointIndex < plate.plate.length; pointIndex++) {
        final point = Offset(
          plate.plate[pointIndex].dx * size.width,
          plate.plate[pointIndex].dy * size.height,
        );
        if (pointIndex == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      final bounds = path.getBounds();
      final plateFill = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: index.isEven
            ? const [Color(0xc30b1620), Color(0xa3162733), Color(0xc309121a)]
            : const [Color(0xc311202b), Color(0xa51a2b37), Color(0xc30a141d)],
      ).createShader(bounds);
      canvas.drawPath(path, Paint()..shader = plateFill);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = const Color(0x665f8495),
      );
      canvas.drawPath(
        path.shift(const Offset(0, 2)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = const Color(0x6610151a),
      );

      for (final bridge in plate.bridgeGearIds) {
        final start = gears[bridge.$1]!.center;
        final end = gears[bridge.$2]!.center;
        canvas.drawLine(
          start,
          end,
          Paint()
            ..strokeWidth = 5.2
            ..strokeCap = StrokeCap.round
            ..color = const Color(0x9c14232e),
        );
        canvas.drawLine(
          start,
          end,
          Paint()
            ..strokeWidth = 1.0
            ..strokeCap = StrokeCap.round
            ..color = const Color(0x5a6f99aa),
        );
      }
      for (final id in plate.mountGearIds) {
        final gear = gears[id]!;
        final seatRadius = gear.pitchRadius * .32 + 7;
        canvas.drawCircle(
          gear.center,
          seatRadius,
          Paint()..color = const Color(0xc4091218),
        );
        canvas.drawCircle(
          gear.center,
          seatRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(0x725a7d8c),
        );
        for (var screw = 0; screw < 3; screw++) {
          final position =
              gear.center +
              Offset.fromDirection(
                screw * math.pi * 2 / 3 + index * .31,
                seatRadius * .72,
              );
          canvas.drawCircle(position, 1.7, Paint()..color = const Color(0xff111d26));
          canvas.drawCircle(
            position,
            1.05,
            Paint()..color = const Color(0x886b8996),
          );
        }
      }
      // A restrained recessed seam implies machining without adding a grid or
      // crossing the foreground UI with bright decoration.
      canvas.drawLine(
        Offset(bounds.left + 14, bounds.top + 14),
        Offset(bounds.right - 14, bounds.top + 14),
        Paint()
          ..strokeWidth = .75
          ..color = const Color(0x443b5a68),
      );
    }
  }

  void _gear(
    Canvas canvas,
    KineticGearGeometry gear,
    double angle,
    int index, {
    bool background = false,
  }) {
    final profile = Path();
    for (var tooth = 0; tooth < gear.renderedToothTipCount; tooth++) {
      final base = angle + tooth * math.pi * 2 / gear.toothCount;
      for (final (fraction, radius) in [
        (-.50, gear.rootRadius),
        (-.27, gear.tipRadius),
        (.22, gear.tipRadius),
        (.50, gear.rootRadius),
      ]) {
        final point =
            gear.center +
            Offset.fromDirection(
              base + fraction * math.pi * 2 / gear.toothCount,
              radius,
            );
        if (tooth == 0 && fraction == -.50) {
          profile.moveTo(point.dx, point.dy);
        } else {
          profile.lineTo(point.dx, point.dy);
        }
      }
    }
    profile.close();
    final fill = background ? const Color(0x9220323f) : const Color(0xff2c4253);
    final edge = background
        ? const Color(0x494d7488)
        : const Color(0xff7acdf0).withValues(alpha: .62);
    final well = background ? const Color(0xc90b1620) : const Color(0xff162634);
    final rim = background ? const Color(0x66456278) : const Color(0xff46687e);
    final spokeColor = background
        ? const Color(0x77344a59)
        : const Color(0xff38566a);
    canvas.drawPath(profile, Paint()..color = fill);
    canvas.drawPath(
      profile,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = edge,
    );
    canvas.drawCircle(
      gear.center,
      gear.pitchRadius * .72,
      Paint()..color = well,
    );
    canvas.drawCircle(
      gear.center,
      gear.pitchRadius * .61,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = gear.pitchRadius * .07
        ..color = rim,
    );
    for (var spoke = 0; spoke < 6; spoke++) {
      final a = angle + spoke * math.pi / 3;
      canvas.drawLine(
        gear.center + Offset.fromDirection(a, gear.pitchRadius * .18),
        gear.center + Offset.fromDirection(a, gear.pitchRadius * .58),
        Paint()
          ..strokeWidth = gear.pitchRadius * .07
          ..strokeCap = StrokeCap.round
          ..color = spokeColor,
      );
    }
    if (!background) {
      canvas.drawCircle(
        gear.center,
        gear.pitchRadius * .22,
        Paint()
          ..color = const Color(0xff68dfff)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawCircle(
      gear.center,
      gear.pitchRadius * .12,
      Paint()
        ..color = background
            ? const Color(0x88617a89)
            : const Color(0xffffbe74),
    );
    canvas.drawArc(
      Rect.fromCircle(center: gear.center, radius: gear.pitchRadius * .82),
      angle + index,
      math.pi * .36,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = gear.pitchRadius * .035
        ..strokeCap = StrokeCap.round
        ..color = background
            ? const Color(0x335b879a)
            : const Color(0xffc1f8ff).withValues(alpha: .62),
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
