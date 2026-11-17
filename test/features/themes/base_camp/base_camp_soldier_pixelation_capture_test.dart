import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/themes/base_camp/base_camp_soldier_motion.dart';
import 'package:or_app/features/themes/base_camp/base_camp_soldier_pixelation.dart';

const _captureDirectory = String.fromEnvironment('SOLDIER_PIXEL_CAPTURE_DIR');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    BaseCampSoldierPixelCache.instance.resetForTesting();
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
  });

  tearDown(BaseCampSoldierPixelCache.instance.resetForTesting);

  for (final level in SoldierPixelationLevel.values) {
    testWidgets('captures Soldier comparison ${level.name}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(720, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      DeviceSettingsController.instance.resetForTesting(
        DeviceSettings(soldierPixelationLevel: level),
      );
      if (level != SoldierPixelationLevel.original) {
        final profile = baseCampSoldierPixelProfile();
        await tester.runAsync(
          () => BaseCampSoldierPixelCache.instance.prepareRequests(
            profile.requests,
            level,
          ),
        );
      }
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xff273326),
            body: RepaintBoundary(
              key: boundaryKey,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _ComparisonCell(
                      label: '${level.controlLabel} · BREATHING',
                      child: const BaseCampBreathingSoldier(dy: -3),
                    ),
                  ),
                  Expanded(
                    child: _ComparisonCell(
                      label: '${level.controlLabel} · REGRIP F3',
                      child: const BaseCampRifleRegripFrame(frame: 3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (level == SoldierPixelationLevel.original) {
        final context = tester.element(find.byType(Scaffold));
        await tester.runAsync(
          () => Future.wait(<Future<void>>[
            precacheImage(
              const AssetImage(baseCampBreathingSoldierLowerAsset),
              context,
            ),
            precacheImage(
              const AssetImage(baseCampBreathingSoldierUpperAsset),
              context,
            ),
            precacheImage(AssetImage(baseCampRifleRegripAssets[3]), context),
          ]),
        );
        await tester.pump();
      }
      if (level != SoldierPixelationLevel.original) {
        for (
          var attempt = 0;
          attempt < 100 &&
              BaseCampSoldierPixelCache.instance.cachedImageCount < 3;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(BaseCampSoldierPixelCache.instance.cachedImageCount, 8);
      } else {
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      if (_captureDirectory.isNotEmpty) {
        final directory = Directory(_captureDirectory)
          ..createSync(recursive: true);
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${directory.path}/soldier_${level.name}_breathing_regrip.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}

class _ComparisonCell extends StatelessWidget {
  const _ComparisonCell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xffaeb894)),
    ),
    child: Column(
      children: <Widget>[
        SizedBox(
          height: 36,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xffaeb894), fontSize: 12),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}
