import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

/// One canonical, vector-only BAT side-profile reference. R→L is a whole
/// canvas mirror, not a second source shape.
class BatSideProfileShapeV1 {
  BatSideProfileShapeV1._();

  static const canvasSize = Size(210, 120);
  static const productionScale = .26;
  static const nearWingColor = Color(0xFF69737C);
  static const farWingColor = Color(0xFF39424A);
  static const bodyColor = Color(0xFF606A73);

  static Path farWingPath() => Path()
    ..moveTo(101, 59)
    ..quadraticBezierTo(81, 37, 56, 25)
    ..quadraticBezierTo(37, 20, 25, 29)
    ..lineTo(36, 43)
    ..quadraticBezierTo(48, 46, 57, 55)
    ..quadraticBezierTo(67, 66, 76, 75)
    ..quadraticBezierTo(87, 69, 101, 66)
    ..close();

  static Path nearWingPath() => Path()
    ..moveTo(104, 59)
    ..quadraticBezierTo(117, 34, 137, 16)
    ..quadraticBezierTo(146, 11, 153, 18)
    ..lineTo(165, 24)
    ..quadraticBezierTo(174, 27, 184, 38)
    ..lineTo(188, 51)
    ..quadraticBezierTo(177, 49, 168, 56)
    ..quadraticBezierTo(158, 63, 151, 72)
    ..quadraticBezierTo(143, 68, 135, 76)
    ..quadraticBezierTo(127, 72, 118, 83)
    ..quadraticBezierTo(112, 77, 102, 72)
    ..close();

  static Path bodyPath() => Path()
    ..moveTo(96, 48)
    ..quadraticBezierTo(104, 42, 115, 47)
    ..lineTo(120, 40)
    ..lineTo(124, 48)
    ..quadraticBezierTo(132, 47, 138, 53)
    ..quadraticBezierTo(144, 57, 141, 61)
    ..lineTo(148, 63)
    ..quadraticBezierTo(143, 67, 135, 66)
    ..quadraticBezierTo(130, 73, 120, 74)
    ..quadraticBezierTo(112, 79, 104, 75)
    ..lineTo(94, 82)
    ..quadraticBezierTo(91, 75, 94, 68)
    ..quadraticBezierTo(89, 59, 96, 48)
    ..close();

  static Path tailMembranePath() => Path()
    ..moveTo(104, 70)
    ..quadraticBezierTo(93, 80, 82, 89)
    ..quadraticBezierTo(94, 91, 107, 83)
    ..quadraticBezierTo(113, 79, 119, 73)
    ..close();

  static List<Path> get authoritativePaths => [
    farWingPath(), nearWingPath(), tailMembranePath(), bodyPath(),
  ];
}

class BatSideProfileShapePoc extends StatefulWidget {
  const BatSideProfileShapePoc({super.key});
  @override
  State<BatSideProfileShapePoc> createState() => _BatSideProfileShapePocState();
}

class _BatSideProfileShapePocState extends State<BatSideProfileShapePoc> {
  var _leftToRight = true;
  var _zoom = 1;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(icon: Icons.nightlight_outlined, title: 'BAT SHAPE POC'),
      AppSpacing.gapSM,
      OperationCard(
        key: const ValueKey('bat-side-profile-shape-poc'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('BAT SIDE PROFILE'),
          const Text('STATIC POSE V1 · VECTOR REFERENCE ONLY'),
          AppSpacing.gapSM,
          _BatCanvas(leftToRight: _leftToRight, scale: _zoom.toDouble(), inspection: true),
          AppSpacing.gapSM,
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(key: const ValueKey('bat-shape-direction-ltr'), onPressed: () => setState(() => _leftToRight = true), child: const Text('L→R')),
            OutlinedButton(key: const ValueKey('bat-shape-direction-rtl'), onPressed: () => setState(() => _leftToRight = false), child: const Text('R→L')),
            for (final zoom in [1, 2, 4]) OutlinedButton(key: ValueKey('bat-shape-zoom-$zoom'), onPressed: () => setState(() => _zoom = zoom), child: Text('$zoom×')),
          ]),
          AppSpacing.gapMD,
          const Text('PRODUCTION-SCALE PREVIEW'),
          Semantics(
            label: 'Bat side profile production scale preview',
            child: SizedBox(key: const ValueKey('bat-shape-production-preview'), height: 48, child: CustomPaint(painter: BatSideProfilePainter(leftToRight: _leftToRight, scale: BatSideProfileShapeV1.productionScale))),
          ),
          AppSpacing.gapSM,
          const Text('One asymmetric side-profile source pose. Near wing dominates; far wing is recessed. No flight, scheduler, or Dashboard integration.'),
        ]),
      ),
    ],
  );
}

class _BatCanvas extends StatelessWidget {
  const _BatCanvas({required this.leftToRight, required this.scale, required this.inspection});
  final bool leftToRight;
  final double scale;
  final bool inspection;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: BatSideProfileShapeV1.canvasSize.height * scale + 8,
    child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(
      key: ValueKey('bat-shape-inspection-${scale.toInt()}'),
      width: BatSideProfileShapeV1.canvasSize.width * scale + 8,
      height: BatSideProfileShapeV1.canvasSize.height * scale + 8,
      child: CustomPaint(painter: BatSideProfilePainter(leftToRight: leftToRight, scale: scale)),
    )),
  );
}

class BatSideProfilePainter extends CustomPainter {
  const BatSideProfilePainter({required this.leftToRight, required this.scale});
  final bool leftToRight;
  final double scale;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF101010));
    final width = BatSideProfileShapeV1.canvasSize.width * scale;
    final height = BatSideProfileShapeV1.canvasSize.height * scale;
    canvas.save();
    canvas.translate((size.width - width) / 2, (size.height - height) / 2);
    if (!leftToRight) { canvas.translate(width, 0); canvas.scale(-1, 1); }
    canvas.scale(scale);
    canvas.drawPath(BatSideProfileShapeV1.farWingPath(), Paint()..color = BatSideProfileShapeV1.farWingColor);
    canvas.drawPath(BatSideProfileShapeV1.nearWingPath(), Paint()..color = BatSideProfileShapeV1.nearWingColor);
    final fingers = Paint()..color = const Color(0x8C9AA5AD)..strokeWidth = 1.1..style = PaintingStyle.stroke;
    for (final finger in [(const Offset(106, 59), const Offset(137, 17)), (const Offset(108, 60), const Offset(164, 25)), (const Offset(109, 62), const Offset(184, 39))]) { canvas.drawLine(finger.$1, finger.$2, fingers); }
    canvas.drawPath(BatSideProfileShapeV1.tailMembranePath(), Paint()..color = BatSideProfileShapeV1.farWingColor);
    canvas.drawPath(BatSideProfileShapeV1.bodyPath(), Paint()..color = BatSideProfileShapeV1.bodyColor);
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant BatSideProfilePainter old) => old.leftToRight != leftToRight || old.scale != scale;
}
