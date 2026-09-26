import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

/// Inspection rendering only. Production Wildlife does not consume this
/// candidate while BAT remains pending.
enum BatInspectionMode { silhouette, anatomy, bodyOnly }

/// Single authoritative, vector-only V2 candidate. Its x axis runs from the
/// compact hind body (left), through torso and shoulder, to the muzzle (right).
/// R→L is a mirror of this same geometry, not a second source pose.
class BatSideProfileShapeV2 {
  BatSideProfileShapeV2._();

  static const canvasSize = Size(228, 128);
  static const productionScale = .26;
  static const silhouetteColor = Color(0xFF707981);
  static const bodyColor = Color(0xFF69727A);
  static const nearWingColor = Color(0xFF7D878F);
  static const farWingColor = Color(0xFF3D474F);
  static const guideColor = Color(0x665D6870);

  /// Recessed and partly occluded: intentionally not a mirrored second wing.
  static Path farWingPath() => Path()
    ..moveTo(105, 58)
    ..quadraticBezierTo(89, 43, 72, 32)
    ..quadraticBezierTo(58, 23, 45, 29)
    ..quadraticBezierTo(48, 39, 60, 48)
    ..quadraticBezierTo(72, 57, 86, 70)
    ..quadraticBezierTo(96, 72, 108, 67)
    ..close();

  /// Shoulder → elbow → forearm → digit fan → membrane contour.
  static Path nearWingPath() => Path()
    ..moveTo(108, 57)
    ..quadraticBezierTo(117, 42, 132, 26)
    ..quadraticBezierTo(145, 12, 158, 15)
    ..quadraticBezierTo(169, 18, 178, 28)
    ..quadraticBezierTo(188, 38, 194, 51)
    ..quadraticBezierTo(182, 49, 170, 56)
    ..quadraticBezierTo(159, 63, 150, 74)
    ..quadraticBezierTo(140, 70, 130, 79)
    ..quadraticBezierTo(120, 75, 111, 82)
    ..quadraticBezierTo(104, 76, 101, 67)
    ..close();

  /// Compact rear membrane, deliberately not a bird-like tail.
  static Path tailMembranePath() => Path()
    ..moveTo(93, 68)
    ..quadraticBezierTo(80, 76, 69, 86)
    ..quadraticBezierTo(81, 89, 94, 84)
    ..quadraticBezierTo(104, 81, 112, 73)
    ..close();

  /// Body-first side profile: short muzzle and near ear at the forward end,
  /// elongated torso, then a compact hind body at the rear.
  static Path bodyPath() => Path()
    ..moveTo(72, 57)
    ..quadraticBezierTo(79, 48, 92, 49)
    ..quadraticBezierTo(104, 48, 115, 53)
    ..lineTo(121, 45)
    ..lineTo(126, 53)
    ..quadraticBezierTo(136, 53, 144, 57)
    ..quadraticBezierTo(151, 56, 157, 60)
    ..lineTo(165, 62)
    ..quadraticBezierTo(169, 64, 164, 66)
    ..lineTo(156, 67)
    ..quadraticBezierTo(146, 74, 130, 75)
    ..quadraticBezierTo(112, 77, 95, 74)
    ..quadraticBezierTo(80, 72, 73, 66)
    ..quadraticBezierTo(69, 62, 72, 57)
    ..close();

  static List<Path> get authoritativePaths => [
    farWingPath(),
    tailMembranePath(),
    nearWingPath(),
    bodyPath(),
  ];

  static List<(Offset, Offset)> get fingerGuides => const [
    (Offset(108, 58), Offset(132, 27)),
    (Offset(110, 59), Offset(158, 16)),
    (Offset(111, 61), Offset(178, 29)),
    (Offset(112, 63), Offset(194, 51)),
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
  var _mode = BatInspectionMode.silhouette;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(
        icon: Icons.nightlight_outlined,
        title: 'BAT SHAPE POC',
      ),
      AppSpacing.gapSM,
      OperationCard(
        key: const ValueKey('bat-side-profile-shape-poc'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('BAT SIDE PROFILE'),
            const Text('STATIC POSE V2 · REFERENCE-DRIVEN CANDIDATE'),
            AppSpacing.gapSM,
            _BatCanvas(
              leftToRight: _leftToRight,
              scale: _zoom.toDouble(),
              mode: _mode,
            ),
            AppSpacing.gapSM,
            const Text('VIEW'),
            AppSpacing.gapSM,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _BatOption(
                  key: const ValueKey('bat-shape-mode-silhouette'),
                  label: 'SILHOUETTE',
                  selected: _mode == BatInspectionMode.silhouette,
                  onPressed: () =>
                      setState(() => _mode = BatInspectionMode.silhouette),
                ),
                _BatOption(
                  key: const ValueKey('bat-shape-mode-anatomy'),
                  label: 'ANATOMY',
                  selected: _mode == BatInspectionMode.anatomy,
                  onPressed: () =>
                      setState(() => _mode = BatInspectionMode.anatomy),
                ),
                _BatOption(
                  key: const ValueKey('bat-shape-mode-body-only'),
                  label: 'BODY ONLY',
                  selected: _mode == BatInspectionMode.bodyOnly,
                  onPressed: () =>
                      setState(() => _mode = BatInspectionMode.bodyOnly),
                ),
              ],
            ),
            AppSpacing.gapMD,
            const Text('DIRECTION'),
            AppSpacing.gapSM,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _BatOption(
                  key: const ValueKey('bat-shape-direction-ltr'),
                  label: 'L→R',
                  selected: _leftToRight,
                  onPressed: () => setState(() => _leftToRight = true),
                ),
                _BatOption(
                  key: const ValueKey('bat-shape-direction-rtl'),
                  label: 'R→L',
                  selected: !_leftToRight,
                  onPressed: () => setState(() => _leftToRight = false),
                ),
                for (final zoom in [1, 2, 4])
                  _BatOption(
                    key: ValueKey('bat-shape-zoom-$zoom'),
                    label: '$zoom×',
                    selected: _zoom == zoom,
                    onPressed: () => setState(() => _zoom = zoom),
                  ),
              ],
            ),
            AppSpacing.gapMD,
            const Text('48PX PRODUCTION-SCALE PREVIEW'),
            Semantics(
              label: 'Bat side profile production scale preview',
              child: SizedBox(
                key: const ValueKey('bat-shape-production-preview'),
                height: 48,
                child: CustomPaint(
                  painter: BatSideProfilePainter(
                    leftToRight: _leftToRight,
                    scale: BatSideProfileShapeV2.productionScale,
                    mode: BatInspectionMode.silhouette,
                  ),
                ),
              ),
            ),
            AppSpacing.gapSM,
            const Text(
              'V2 body-first source: side-facing head, elongated torso, dominant near membrane wing, and recessed far wing. Sandbox only; no BAT flight, scheduler, or Dashboard activation.',
            ),
          ],
        ),
      ),
    ],
  );
}

class _BatOption extends StatelessWidget {
  const _BatOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: selected
        ? OutlinedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          )
        : null,
    child: Text(label),
  );
}

class _BatCanvas extends StatelessWidget {
  const _BatCanvas({
    required this.leftToRight,
    required this.scale,
    required this.mode,
  });

  final bool leftToRight;
  final double scale;
  final BatInspectionMode mode;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: BatSideProfileShapeV2.canvasSize.height * scale + 8,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        key: ValueKey('bat-shape-inspection-${scale.toInt()}'),
        width: BatSideProfileShapeV2.canvasSize.width * scale + 8,
        height: BatSideProfileShapeV2.canvasSize.height * scale + 8,
        child: CustomPaint(
          painter: BatSideProfilePainter(
            leftToRight: leftToRight,
            scale: scale,
            mode: mode,
          ),
        ),
      ),
    ),
  );
}

class BatSideProfilePainter extends CustomPainter {
  const BatSideProfilePainter({
    required this.leftToRight,
    required this.scale,
    required this.mode,
  });

  final bool leftToRight;
  final double scale;
  final BatInspectionMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF101010),
    );
    final width = BatSideProfileShapeV2.canvasSize.width * scale;
    final height = BatSideProfileShapeV2.canvasSize.height * scale;
    canvas.save();
    canvas.translate((size.width - width) / 2, (size.height - height) / 2);
    if (!leftToRight) {
      canvas.translate(width, 0);
      canvas.scale(-1, 1);
    }
    canvas.scale(scale);
    final silhouette = mode == BatInspectionMode.silhouette;
    final bodyOnly = mode == BatInspectionMode.bodyOnly;
    if (!bodyOnly) {
      canvas.drawPath(
        BatSideProfileShapeV2.farWingPath(),
        Paint()
          ..color = silhouette
              ? BatSideProfileShapeV2.silhouetteColor
              : BatSideProfileShapeV2.farWingColor,
      );
      canvas.drawPath(
        BatSideProfileShapeV2.nearWingPath(),
        Paint()
          ..color = silhouette
              ? BatSideProfileShapeV2.silhouetteColor
              : BatSideProfileShapeV2.nearWingColor,
      );
      if (mode == BatInspectionMode.anatomy) {
        final fingers = Paint()
          ..color = BatSideProfileShapeV2.guideColor
          ..strokeWidth = 1.15
          ..style = PaintingStyle.stroke;
        for (final guide in BatSideProfileShapeV2.fingerGuides) {
          canvas.drawLine(guide.$1, guide.$2, fingers);
        }
      }
    }
    canvas.drawPath(
      BatSideProfileShapeV2.tailMembranePath(),
      Paint()
        ..color = silhouette
            ? BatSideProfileShapeV2.silhouetteColor
            : BatSideProfileShapeV2.farWingColor,
    );
    canvas.drawPath(
      BatSideProfileShapeV2.bodyPath(),
      Paint()
        ..color = silhouette
            ? BatSideProfileShapeV2.silhouetteColor
            : BatSideProfileShapeV2.bodyColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BatSideProfilePainter old) =>
      old.leftToRight != leftToRight || old.scale != scale || old.mode != mode;
}
