import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_helicopter.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_map.dart';

const _captureDirectory = String.fromEnvironment('HELICOPTER_CAPTURE_DIR');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final scenario
      in <
        ({
          String name,
          BaseCampHelicopterDirection direction,
          int mainFrame,
          int tailFrame,
        })
      >[
        (
          name: 'left_to_right',
          direction: BaseCampHelicopterDirection.leftToRight,
          mainFrame: 1,
          tailFrame: 4,
        ),
        (
          name: 'right_to_left',
          direction: BaseCampHelicopterDirection.rightToLeft,
          mainFrame: 4,
          tailFrame: 12,
        ),
        (
          name: 'rotors_active',
          direction: BaseCampHelicopterDirection.leftToRight,
          mainFrame: 5,
          tailFrame: 15,
        ),
      ]) {
    testWidgets('captures helicopter ${scenario.name}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 390));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final interactive = ValueNotifier<bool>(false);
      addTearDown(interactive.dispose);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xff293022),
            body: RepaintBoundary(
              key: boundaryKey,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  const Image(
                    image: baseCampMapImageProvider,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                  BaseCampHelicopterFlybyLayer(
                    dashboardInteractive: interactive,
                    debugFlight: BaseCampHelicopterDebugFlight(
                      progress: .5,
                      direction: scenario.direction,
                      altitudeFactor: .08,
                      mainRotorFrame: scenario.mainFrame,
                      tailRotorFrame: scenario.tailFrame,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(Scaffold));
      await tester.runAsync(
        () => Future.wait(<Future<void>>[
          precacheImage(baseCampMapImageProvider, context),
          precacheImage(const AssetImage(baseCampHelicopterBodyAsset), context),
          precacheImage(
            AssetImage(baseCampHelicopterMainRotorAssets[scenario.mainFrame]),
            context,
          ),
          precacheImage(
            AssetImage(baseCampHelicopterTailRotorAssets[scenario.tailFrame]),
            context,
          ),
        ]),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (_captureDirectory.isEmpty) return;
      final directory = Directory(_captureDirectory)
        ..createSync(recursive: true);
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${directory.path}/helicopter_${scenario.name}.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
