import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

/// Diagnostic render modes. Production Wildlife does not consume this source
/// while BAT remains pending.
enum BatInspectionMode { silhouette, anatomy, bodyOnly }

/// One authoritative, vector-only BAT V3 candidate. The source faces right;
/// R→L is a whole-canvas mirror. Body construction is independent of wings.
class BatSideProfileShapeV3 {
  BatSideProfileShapeV3._();

  static const canvasSize = Size(228, 128);
  static const productionScale = .26;
  static const silhouetteColor = Color(0xFF737C84);
  static const bodyColor = Color(0xFF68717A);
  static const nearWingColor = Color(0xFF808B93);
  static const farWingColor = Color(0xFF3B454D);
  static const guideColor = Color(0x775C6770);

  static const nearEarTip = Offset(151, 40);
  static const farEarTip = Offset(136, 45);
  static const muzzleTip = Offset(180, 65);
  static const nearWingTip = Offset(202, 43);

  /// Partial, integrated far wing behind the shoulder and torso: no paddle.
  static Path farWingPath() => Path()
    ..moveTo(115, 61)
    ..lineTo(98, 46)
    ..lineTo(78, 32)
    ..quadraticBezierTo(66, 27, 57, 34)
    ..lineTo(64, 43)
    ..quadraticBezierTo(75, 48, 85, 57)
    ..quadraticBezierTo(95, 66, 108, 71)
    ..lineTo(119, 67)
    ..close();

  /// The outer contour itself describes shoulder, elbow, wrist, digit tips,
  /// and three membrane bays; anatomy guides merely clarify that geometry.
  static Path nearWingPath() => Path()
    ..moveTo(117, 61)
    ..lineTo(131, 47)
    ..lineTo(151, 25)
    ..lineTo(169, 13)
    ..lineTo(184, 18)
    ..lineTo(195, 29)
    ..lineTo(202, 43)
    ..quadraticBezierTo(190, 46, 179, 55)
    ..quadraticBezierTo(168, 52, 157, 64)
    ..quadraticBezierTo(146, 61, 136, 74)
    ..quadraticBezierTo(126, 71, 117, 82)
    ..quadraticBezierTo(110, 77, 108, 69)
    ..close();

  /// Compact hind-leg and rear-membrane cue, without a fish or bird tail.
  static Path tailMembranePath() => Path()
    ..moveTo(94, 72)
    ..lineTo(84, 81)
    ..lineTo(74, 88)
    ..quadraticBezierTo(83, 92, 94, 88)
    ..lineTo(102, 82)
    ..lineTo(109, 75)
    ..close();

  /// Mammalian side profile: organic torso, shoulder notch, two ear peaks,
  /// and a short blunt muzzle that establishes rightward travel.
  static Path bodyPath() => Path()
    ..moveTo(72, 62)
    ..quadraticBezierTo(79, 53, 92, 53)
    ..quadraticBezierTo(104, 52, 115, 57)
    ..lineTo(124, 61)
    ..quadraticBezierTo(128, 55, 133, 53)
    ..lineTo(136, 45)
    ..lineTo(142, 53)
    ..quadraticBezierTo(146, 52, 148, 54)
    ..lineTo(151, 40)
    ..lineTo(158, 56)
    ..quadraticBezierTo(164, 57, 168, 61)
    ..lineTo(177, 62)
    ..quadraticBezierTo(182, 64, 180, 66)
    ..lineTo(176, 69)
    ..lineTo(168, 69)
    ..quadraticBezierTo(159, 77, 145, 79)
    ..quadraticBezierTo(128, 81, 111, 77)
    ..quadraticBezierTo(96, 78, 83, 73)
    ..quadraticBezierTo(73, 70, 70, 66)
    ..quadraticBezierTo(69, 64, 72, 62)
    ..close();

  static List<Path> get authoritativePaths => [
    farWingPath(),
    tailMembranePath(),
    nearWingPath(),
    bodyPath(),
  ];

  static List<(Offset, Offset)> get anatomyGuides => const [
    (Offset(120, 61), Offset(132, 47)),
    (Offset(132, 47), Offset(151, 25)),
    (Offset(151, 25), Offset(169, 13)),
    (Offset(152, 27), Offset(184, 18)),
    (Offset(153, 29), Offset(195, 29)),
    (Offset(154, 31), Offset(202, 43)),
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
            const Text('STATIC POSE V3 · IDENTITY / SILHOUETTE CANDIDATE'),
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
            const Text('48PX PRODUCTION-SCALE SILHOUETTE'),
            Semantics(
              label: 'Bat side profile production scale silhouette preview',
              child: SizedBox(
                key: const ValueKey('bat-shape-production-preview'),
                height: 48,
                child: CustomPaint(
                  painter: BatSideProfilePainter(
                    leftToRight: _leftToRight,
                    scale: BatSideProfileShapeV3.productionScale,
                    mode: BatInspectionMode.silhouette,
                  ),
                ),
              ),
            ),
            AppSpacing.gapSM,
            const Text(
              'V3: two-ear head and blunt muzzle, body-first mammal axis, angular digit-led near wing, three membrane bays, and a recessed far wing. Sandbox only; no flight, scheduler, or Dashboard BAT.',
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
    height: BatSideProfileShapeV3.canvasSize.height * scale + 8,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        key: ValueKey('bat-shape-inspection-${scale.toInt()}'),
        width: BatSideProfileShapeV3.canvasSize.width * scale + 8,
        height: BatSideProfileShapeV3.canvasSize.height * scale + 8,
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
    final width = BatSideProfileShapeV3.canvasSize.width * scale;
    final height = BatSideProfileShapeV3.canvasSize.height * scale;
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
        BatSideProfileShapeV3.farWingPath(),
        Paint()
          ..color = silhouette
              ? BatSideProfileShapeV3.silhouetteColor
              : BatSideProfileShapeV3.farWingColor,
      );
      canvas.drawPath(
        BatSideProfileShapeV3.nearWingPath(),
        Paint()
          ..color = silhouette
              ? BatSideProfileShapeV3.silhouetteColor
              : BatSideProfileShapeV3.nearWingColor,
      );
      if (mode == BatInspectionMode.anatomy) {
        final guidePaint = Paint()
          ..color = BatSideProfileShapeV3.guideColor
          ..strokeWidth = 1.1
          ..style = PaintingStyle.stroke;
        for (final guide in BatSideProfileShapeV3.anatomyGuides) {
          canvas.drawLine(guide.$1, guide.$2, guidePaint);
        }
      }
    }
    canvas.drawPath(
      BatSideProfileShapeV3.tailMembranePath(),
      Paint()
        ..color = silhouette
            ? BatSideProfileShapeV3.silhouetteColor
            : BatSideProfileShapeV3.farWingColor,
    );
    canvas.drawPath(
      BatSideProfileShapeV3.bodyPath(),
      Paint()
        ..color = silhouette
            ? BatSideProfileShapeV3.silhouetteColor
            : BatSideProfileShapeV3.bodyColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BatSideProfilePainter old) =>
      old.leftToRight != leftToRight || old.scale != scale || old.mode != mode;
}
