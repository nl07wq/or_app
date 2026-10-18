import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/dashboard/dashboard_page.dart';

void main() {
  const probeSize = 90.0;

  Future<ui.Image> captureLogo(
    WidgetTester tester,
    DashboardNeonFaultPhase phase,
  ) async {
    const boundaryKey = ValueKey('dashboard-logo-alpha-probe');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox.square(
              dimension: probeSize,
              child: Center(child: DashboardNeonLogo(phase: phase)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    return (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
  }

  testWidgets('all colour layers are constrained by the emblem alpha mask', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: DashboardNeonLogo(phase: DashboardNeonFaultPatterns.stable),
      ),
    );
    await tester.pumpAndSettle();

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, hasLength(3));
    expect(
      images.map((image) => image.colorBlendMode),
      containsAll([BlendMode.srcIn, BlendMode.srcIn, null]),
    );
    expect(
      images.where((image) => image.colorBlendMode == BlendMode.plus),
      isEmpty,
    );
  });

  testWidgets('pixels away from the local glow remain fully transparent', (
    tester,
  ) async {
    final image = await captureLogo(tester, DashboardNeonFaultPatterns.stable);
    final bytes = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    expect(bytes, isNotNull);
    final rgba = bytes!.buffer.asUint8List();
    final width = image.width;
    final height = image.height;

    int alphaAt(int x, int y) => rgba[(y * width + x) * 4 + 3];
    var illuminatedPixels = 0;
    var remoteAlphaPixels = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final alpha = alphaAt(x, y);
        if (alpha > 0) illuminatedPixels++;
        if ((x < 12 || x >= width - 12 || y < 12 || y >= height - 12) &&
            alpha > 0) {
          remoteAlphaPixels++;
        }
      }
    }

    expect(illuminatedPixels, greaterThan(0));
    expect(remoteAlphaPixels, 0);
    for (final point in [
      const Offset(0, 0),
      Offset(width - 1.0, 0),
      Offset(0, height - 1.0),
      Offset(width - 1.0, height - 1.0),
    ]) {
      expect(alphaAt(point.dx.toInt(), point.dy.toInt()), 0);
    }
    image.dispose();
  });

  testWidgets('fault blackout removes core edge and glow without residue', (
    tester,
  ) async {
    const off = DashboardNeonFaultPhase(
      duration: Duration(milliseconds: 80),
      coreIntensity: 0,
      innerGlowIntensity: 0,
      outerGlowIntensity: 0,
      logoIntensity: 0,
      frameTubeIntensity: 0,
      frameReflectionIntensity: 0,
    );
    final image = await captureLogo(tester, off);
    final bytes = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    final rgba = bytes!.buffer.asUint8List();
    expect(
      Iterable<int>.generate(
        image.width * image.height,
        (index) => rgba[index * 4 + 3],
      ).every((alpha) => alpha == 0),
      isTrue,
    );
    image.dispose();
  });

  testWidgets('logo glow remains local on four diagnostic backgrounds', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 120));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: Color(0xff10151d),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LogoBackground(color: Colors.black),
                _LogoBackground(color: Color(0xff182633)),
                _LogoBackground(color: Color(0xffb8bdc4)),
                _LogoBackground(checkerboard: true),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Row),
      matchesGoldenFile(
        'goldens/dashboard_neon_logo_v2_4_transparency_backgrounds.png',
      ),
    );
  });
}

class _LogoBackground extends StatelessWidget {
  const _LogoBackground({this.color, this.checkerboard = false});

  final Color? color;
  final bool checkerboard;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 90,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (checkerboard)
            const CustomPaint(painter: _CheckerboardPainter())
          else
            ColoredBox(color: color!),
          const Center(
            child: DashboardNeonLogo(phase: DashboardNeonFaultPatterns.stable),
          ),
        ],
      ),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const tileSize = 9.0;
    final light = Paint()..color = const Color(0xffd7d9dc);
    final dark = Paint()..color = const Color(0xff7f858c);
    for (var row = 0; row < (size.height / tileSize).ceil(); row++) {
      for (var column = 0; column < (size.width / tileSize).ceil(); column++) {
        canvas.drawRect(
          Rect.fromLTWH(column * tileSize, row * tileSize, tileSize, tileSize),
          (row + column).isEven ? light : dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerboardPainter oldDelegate) => false;
}
