import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';

/// A traced source frame. Every contour is independently derived from one of
/// the five supplied silhouettes; only body-root registration is shared.
class BatSourceMotionFrame {
  const BatSourceMotionFrame({
    required this.sourceIndex,
    required this.contour,
    required this.bodyAnchor,
    required this.bodyScale,
  });

  final int sourceIndex;
  final Path Function() contour;
  final Offset bodyAnchor;
  final double bodyScale;
}

/// Source-derived discrete BAT motion data. The common body anchor is the
/// head/shoulder/torso registration root, not the changing wing bounds.
class BatFlightMotionSource {
  BatFlightMotionSource._();

  static const canvasSize = Size(280, 160);
  static const frameDuration = Duration(milliseconds: 70);
  static const bodyAnchor = Offset(145, 84);
  static const bodyAnchorTolerance = 1.0;
  static const pingPongSequence = [0, 1, 2, 3, 4, 3, 2, 1];

  static final frames = <BatSourceMotionFrame>[
    BatSourceMotionFrame(
      sourceIndex: 1,
      contour: _frame01,
      bodyAnchor: bodyAnchor,
      bodyScale: 1,
    ),
    BatSourceMotionFrame(
      sourceIndex: 2,
      contour: _frame02,
      bodyAnchor: bodyAnchor,
      bodyScale: 1,
    ),
    BatSourceMotionFrame(
      sourceIndex: 3,
      contour: _frame03,
      bodyAnchor: bodyAnchor,
      bodyScale: 1,
    ),
    BatSourceMotionFrame(
      sourceIndex: 4,
      contour: _frame04,
      bodyAnchor: bodyAnchor,
      bodyScale: 1,
    ),
    BatSourceMotionFrame(
      sourceIndex: 5,
      contour: _frame05,
      bodyAnchor: bodyAnchor,
      bodyScale: 1,
    ),
  ];

  // FRAME 01 — source image 01: raised rear wing and extended forward wing.
  static Path _frame01() => Path()
    ..moveTo(182, 84)
    ..lineTo(176, 75)
    ..lineTo(170, 69)
    ..lineTo(166, 77)
    ..lineTo(160, 72)
    ..lineTo(154, 79)
    ..lineTo(147, 76)
    ..lineTo(125, 54)
    ..lineTo(96, 25)
    ..lineTo(70, 11)
    ..lineTo(45, 10)
    ..quadraticBezierTo(53, 16, 37, 25)
    ..lineTo(14, 37)
    ..quadraticBezierTo(37, 39, 45, 56)
    ..quadraticBezierTo(56, 74, 46, 89)
    ..quadraticBezierTo(63, 86, 73, 100)
    ..quadraticBezierTo(85, 113, 72, 126)
    ..lineTo(82, 121)
    ..lineTo(76, 133)
    ..quadraticBezierTo(91, 126, 100, 115)
    ..quadraticBezierTo(124, 120, 143, 109)
    ..quadraticBezierTo(154, 106, 161, 99)
    ..quadraticBezierTo(170, 100, 177, 96)
    ..lineTo(184, 94)
    ..quadraticBezierTo(190, 91, 184, 86)
    ..close()
    ..moveTo(150, 78)
    ..lineTo(178, 55)
    ..lineTo(209, 34)
    ..quadraticBezierTo(235, 20, 264, 20)
    ..quadraticBezierTo(238, 27, 218, 42)
    ..lineTo(191, 67)
    ..quadraticBezierTo(181, 75, 176, 83)
    ..close();

  // FRAME 02 — source image 02: the same source phase, slightly compressed.
  static Path _frame02() => Path()
    ..moveTo(181, 85)
    ..lineTo(175, 76)
    ..lineTo(169, 70)
    ..lineTo(165, 78)
    ..lineTo(159, 73)
    ..lineTo(153, 80)
    ..lineTo(146, 77)
    ..lineTo(124, 57)
    ..lineTo(96, 29)
    ..lineTo(70, 16)
    ..lineTo(45, 15)
    ..quadraticBezierTo(53, 20, 37, 29)
    ..lineTo(16, 40)
    ..quadraticBezierTo(39, 43, 46, 59)
    ..quadraticBezierTo(56, 75, 48, 91)
    ..quadraticBezierTo(64, 89, 75, 102)
    ..quadraticBezierTo(86, 114, 75, 126)
    ..lineTo(84, 122)
    ..lineTo(79, 133)
    ..quadraticBezierTo(93, 127, 101, 116)
    ..quadraticBezierTo(122, 120, 142, 110)
    ..quadraticBezierTo(154, 107, 162, 100)
    ..quadraticBezierTo(170, 101, 177, 97)
    ..lineTo(183, 94)
    ..quadraticBezierTo(189, 92, 181, 85)
    ..close()
    ..moveTo(150, 79)
    ..lineTo(178, 57)
    ..lineTo(210, 38)
    ..quadraticBezierTo(237, 27, 263, 29)
    ..quadraticBezierTo(239, 34, 218, 48)
    ..lineTo(192, 69)
    ..quadraticBezierTo(181, 77, 175, 84)
    ..close();

  // FRAME 03 — source image 03: broad, nearly horizontal extended wings.
  static Path _frame03() => Path()
    ..moveTo(184, 81)
    ..lineTo(178, 72)
    ..lineTo(172, 66)
    ..lineTo(168, 75)
    ..lineTo(162, 69)
    ..lineTo(156, 77)
    ..lineTo(146, 73)
    ..quadraticBezierTo(115, 61, 86, 60)
    ..quadraticBezierTo(51, 60, 22, 77)
    ..lineTo(12, 84)
    ..quadraticBezierTo(30, 84, 43, 92)
    ..quadraticBezierTo(58, 102, 73, 98)
    ..quadraticBezierTo(74, 111, 88, 114)
    ..quadraticBezierTo(106, 111, 123, 103)
    ..lineTo(146, 89)
    ..quadraticBezierTo(156, 94, 165, 96)
    ..quadraticBezierTo(172, 95, 179, 91)
    ..lineTo(186, 88)
    ..quadraticBezierTo(191, 84, 184, 81)
    ..close()
    ..moveTo(150, 75)
    ..quadraticBezierTo(179, 70, 201, 79)
    ..quadraticBezierTo(235, 92, 263, 121)
    ..quadraticBezierTo(239, 105, 218, 98)
    ..quadraticBezierTo(204, 91, 190, 94)
    ..quadraticBezierTo(179, 86, 171, 83)
    ..close();

  // FRAME 04 — source image 04: high vertical near wing and dropped rear wing.
  static Path _frame04() => Path()
    ..moveTo(184, 84)
    ..lineTo(178, 75)
    ..lineTo(172, 68)
    ..lineTo(168, 77)
    ..lineTo(162, 71)
    ..lineTo(156, 79)
    ..lineTo(147, 76)
    ..lineTo(130, 68)
    ..lineTo(105, 91)
    ..lineTo(81, 114)
    ..quadraticBezierTo(65, 128, 46, 130)
    ..quadraticBezierTo(58, 139, 78, 130)
    ..lineTo(71, 145)
    ..quadraticBezierTo(89, 139, 103, 125)
    ..quadraticBezierTo(123, 113, 142, 107)
    ..quadraticBezierTo(154, 106, 162, 99)
    ..quadraticBezierTo(172, 100, 179, 96)
    ..lineTo(186, 93)
    ..quadraticBezierTo(191, 88, 184, 84)
    ..close()
    ..moveTo(147, 76)
    ..lineTo(157, 49)
    ..lineTo(173, 22)
    ..lineTo(184, 5)
    ..quadraticBezierTo(199, 20, 199, 42)
    ..quadraticBezierTo(198, 60, 210, 71)
    ..quadraticBezierTo(193, 68, 182, 79)
    ..lineTo(170, 94)
    ..lineTo(160, 98)
    ..close();

  // FRAME 05 — source image 05: return to the raised/reaching source pose.
  static Path _frame05() => Path()
    ..moveTo(183, 85)
    ..lineTo(177, 76)
    ..lineTo(171, 69)
    ..lineTo(167, 78)
    ..lineTo(160, 73)
    ..lineTo(154, 80)
    ..lineTo(147, 77)
    ..lineTo(124, 55)
    ..lineTo(97, 26)
    ..lineTo(72, 12)
    ..lineTo(47, 11)
    ..quadraticBezierTo(54, 17, 39, 26)
    ..lineTo(17, 38)
    ..quadraticBezierTo(39, 40, 47, 57)
    ..quadraticBezierTo(58, 74, 48, 90)
    ..quadraticBezierTo(65, 88, 76, 101)
    ..quadraticBezierTo(88, 113, 76, 127)
    ..lineTo(85, 122)
    ..lineTo(80, 135)
    ..quadraticBezierTo(94, 128, 102, 116)
    ..quadraticBezierTo(124, 120, 143, 110)
    ..quadraticBezierTo(154, 107, 162, 100)
    ..quadraticBezierTo(171, 101, 178, 97)
    ..lineTo(185, 94)
    ..quadraticBezierTo(190, 90, 183, 85)
    ..close()
    ..moveTo(151, 79)
    ..lineTo(179, 56)
    ..lineTo(210, 36)
    ..quadraticBezierTo(238, 24, 266, 26)
    ..quadraticBezierTo(240, 33, 219, 47)
    ..lineTo(192, 69)
    ..quadraticBezierTo(181, 77, 175, 84)
    ..close();
}

class BatFlightMotionPoc extends StatefulWidget {
  const BatFlightMotionPoc({super.key});

  @override
  State<BatFlightMotionPoc> createState() => _BatFlightMotionPocState();
}

class _BatFlightMotionPocState extends State<BatFlightMotionPoc> {
  var _frameIndex = 0;
  var _sequenceIndex = 0;
  var _leftToRight = true;
  var _zoom = 1;
  Timer? _timer;

  bool get _playing => _timer != null;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setFrame(int index) {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _frameIndex = index;
      _sequenceIndex = BatFlightMotionSource.pingPongSequence.indexOf(index);
    });
  }

  void _next() =>
      _setFrame((_frameIndex + 1) % BatFlightMotionSource.frames.length);

  void _previous() => _setFrame(
    (_frameIndex - 1 + BatFlightMotionSource.frames.length) %
        BatFlightMotionSource.frames.length,
  );

  void _togglePlayback() {
    if (_playing) {
      _timer?.cancel();
      setState(() => _timer = null);
      return;
    }
    _timer = Timer.periodic(BatFlightMotionSource.frameDuration, (_) {
      if (!mounted) return;
      setState(() {
        _sequenceIndex =
            (_sequenceIndex + 1) %
            BatFlightMotionSource.pingPongSequence.length;
        _frameIndex = BatFlightMotionSource.pingPongSequence[_sequenceIndex];
      });
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(
        icon: Icons.motion_photos_on_outlined,
        title: 'BAT MOTION POC',
      ),
      AppSpacing.gapSM,
      OperationCard(
        key: const ValueKey('bat-motion-poc'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('5-FRAME SOURCE MOTION · DISCRETE VECTOR PLAYBACK'),
            Text('FRAME ${(_frameIndex + 1).toString().padLeft(2, '0')}'),
            AppSpacing.gapSM,
            _BatMotionCanvas(
              frameIndex: _frameIndex,
              leftToRight: _leftToRight,
              scale: _zoom.toDouble(),
            ),
            AppSpacing.gapSM,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MotionButton(
                  key: const ValueKey('bat-motion-prev'),
                  label: 'PREV',
                  onPressed: _previous,
                ),
                _MotionButton(
                  key: const ValueKey('bat-motion-next'),
                  label: 'NEXT',
                  onPressed: _next,
                ),
                _MotionButton(
                  key: const ValueKey('bat-motion-play-pause'),
                  label: _playing ? 'PAUSE' : 'PLAY',
                  onPressed: _togglePlayback,
                ),
                for (
                  var index = 0;
                  index < BatFlightMotionSource.frames.length;
                  index++
                )
                  _MotionButton(
                    key: ValueKey('bat-motion-frame-${index + 1}'),
                    label: 'FRAME ${(index + 1).toString().padLeft(2, '0')}',
                    onPressed: () => _setFrame(index),
                  ),
              ],
            ),
            AppSpacing.gapMD,
            const Text('DIRECTION / INSPECTION SCALE'),
            AppSpacing.gapSM,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MotionButton(
                  key: const ValueKey('bat-motion-direction-ltr'),
                  label: 'L→R',
                  onPressed: () => setState(() => _leftToRight = true),
                ),
                _MotionButton(
                  key: const ValueKey('bat-motion-direction-rtl'),
                  label: 'R→L',
                  onPressed: () => setState(() => _leftToRight = false),
                ),
                for (final zoom in [1, 2, 4])
                  _MotionButton(
                    key: ValueKey('bat-motion-zoom-$zoom'),
                    label: '$zoom×',
                    onPressed: () => setState(() => _zoom = zoom),
                  ),
              ],
            ),
            AppSpacing.gapMD,
            const Text('48PX WILDLIFE PREVIEW'),
            Semantics(
              label: 'Bat five frame motion production scale preview',
              child: SizedBox(
                key: const ValueKey('bat-motion-production-preview'),
                height: 48,
                child: CustomPaint(
                  painter: BatMotionPainter(
                    frameIndex: _frameIndex,
                    leftToRight: _leftToRight,
                    scale: .22,
                  ),
                ),
              ),
            ),
            AppSpacing.gapSM,
            const Text(
              'Frames 01→02→03→04→05→04→03→02 at 70ms. Registered on head/shoulder/torso root; wing bounds retain their source-specific extent. Source rasters are not bundled or used at runtime.',
            ),
          ],
        ),
      ),
    ],
  );
}

class _MotionButton extends StatelessWidget {
  const _MotionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      OutlinedButton(onPressed: onPressed, child: Text(label));
}

class _BatMotionCanvas extends StatelessWidget {
  const _BatMotionCanvas({
    required this.frameIndex,
    required this.leftToRight,
    required this.scale,
  });

  final int frameIndex;
  final bool leftToRight;
  final double scale;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: BatFlightMotionSource.canvasSize.height * scale + 8,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        key: ValueKey('bat-motion-inspection-${scale.toInt()}'),
        width: BatFlightMotionSource.canvasSize.width * scale + 8,
        height: BatFlightMotionSource.canvasSize.height * scale + 8,
        child: CustomPaint(
          painter: BatMotionPainter(
            frameIndex: frameIndex,
            leftToRight: leftToRight,
            scale: scale,
          ),
        ),
      ),
    ),
  );
}

class BatMotionPainter extends CustomPainter {
  const BatMotionPainter({
    required this.frameIndex,
    required this.leftToRight,
    required this.scale,
  });

  final int frameIndex;
  final bool leftToRight;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF101010),
    );
    final width = BatFlightMotionSource.canvasSize.width * scale;
    final height = BatFlightMotionSource.canvasSize.height * scale;
    canvas.save();
    canvas.translate((size.width - width) / 2, (size.height - height) / 2);
    if (!leftToRight) {
      canvas.translate(width, 0);
      canvas.scale(-1, 1);
    }
    canvas.scale(scale);
    canvas.drawPath(
      BatFlightMotionSource.frames[frameIndex].contour(),
      Paint()..color = const Color(0xFF737C84),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BatMotionPainter old) =>
      old.frameIndex != frameIndex ||
      old.leftToRight != leftToRight ||
      old.scale != scale;
}
