import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/dashboard/dashboard_page.dart';

void main() {
  const probeSize = 90.0;
  const logoAsset = 'assets/icons/dashboard_orlo_emblem_128_transparent.png';
  const masterAsset = 'assets/icons/dashboard_orlo_emblem_1290_transparent.png';

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

  testWidgets(
    'uses the supplied 128px RGBA emblem without changing its visible bounds',
    (tester) async {
      Future<ui.Image> decodeAsset(String asset) async {
        final data = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        return frame.image;
      }

      final logo = await tester.runAsync(() => decodeAsset(logoAsset));
      final master = await tester.runAsync(() => decodeAsset(masterAsset));
      expect(logo, isNotNull);
      expect(master, isNotNull);
      expect(logo!.width, 128);
      expect(logo.height, 128);

      Future<List<int>> cornersOf(ui.Image image) async {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final rgba = data!.buffer.asUint8List();
        int alphaAt(int x, int y) => rgba[(y * image.width + x) * 4 + 3];
        return [
          alphaAt(0, 0),
          alphaAt(image.width - 1, 0),
          alphaAt(0, image.height - 1),
          alphaAt(image.width - 1, image.height - 1),
        ];
      }

      expect(await tester.runAsync(() => cornersOf(logo)), [0, 0, 0, 0]);
      expect(await tester.runAsync(() => cornersOf(master!)), [0, 0, 0, 0]);

      final logoPixels = await tester.runAsync(
        () => logo.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      final masterPixels = await tester.runAsync(
        () => master!.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      Rect nonTransparentBounds(ui.Image image, ByteData pixels) {
        final rgba = pixels.buffer.asUint8List();
        var minX = image.width;
        var minY = image.height;
        var maxX = -1;
        var maxY = -1;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            if (rgba[(y * image.width + x) * 4 + 3] == 0) continue;
            minX = math.min(minX, x);
            minY = math.min(minY, y);
            maxX = math.max(maxX, x);
            maxY = math.max(maxY, y);
          }
        }
        return Rect.fromLTRB(
          minX.toDouble(),
          minY.toDouble(),
          maxX + 1.0,
          maxY + 1.0,
        );
      }

      final logoBounds = nonTransparentBounds(logo, logoPixels!);
      final masterBounds = nonTransparentBounds(master!, masterPixels!);
      expect(
        logoBounds.left / logo.width,
        closeTo(masterBounds.left / master.width, .01),
      );
      expect(
        logoBounds.top / logo.height,
        closeTo(masterBounds.top / master.height, .01),
      );
      expect(
        logoBounds.right / logo.width,
        closeTo(masterBounds.right / master.width, .01),
      );
      expect(
        logoBounds.bottom / logo.height,
        closeTo(masterBounds.bottom / master.height, .01),
      );
      logo.dispose();
      master.dispose();
    },
  );

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
