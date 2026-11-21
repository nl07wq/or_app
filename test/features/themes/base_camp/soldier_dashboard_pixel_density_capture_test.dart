import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/themes/base_camp/base_camp_soldier_motion.dart';
import 'package:or_app/features/themes/base_camp/base_camp_soldier_pixelation.dart';

const _captureDirectory = String.fromEnvironment(
  'SOLDIER_DASHBOARD_DENSITY_CAPTURE_DIR',
);
const _viewports = <int, Size>{
  320: Size(91.7, 82),
  375: Size(113.7, 82),
  390: Size(119.7, 82),
  430: Size(135.7, 82),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
    BaseCampSoldierPixelCache.instance.resetForTesting();
  });

  tearDown(BaseCampSoldierPixelCache.instance.resetForTesting);

  for (final viewportEntry in _viewports.entries) {
    for (final dpr in <double>[2, 3]) {
      for (final motion in BaseCampSoldierMotion.values) {
        for (final level in SoldierPixelationLevel.values) {
          testWidgets('renders ${viewportEntry.key}dp DPR$dpr Dashboard '
              '${motion.name} ${level.controlLabel}', (tester) async {
            final viewport = viewportEntry.value;
            tester.view.devicePixelRatio = dpr;
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.binding.setSurfaceSize(viewport);
            addTearDown(() => tester.binding.setSurfaceSize(null));
            DeviceSettingsController.instance.resetForTesting(
              DeviceSettings(
                breathingPixelLevel: motion == BaseCampSoldierMotion.breathing
                    ? level
                    : SoldierPixelationLevel.original,
                regripPixelLevel: motion == BaseCampSoldierMotion.regrip
                    ? level
                    : SoldierPixelationLevel.original,
              ),
            );
            final profile = baseCampSoldierPixelProfile(
              viewport: viewport,
              devicePixelRatio: dpr,
              density: BaseCampSoldierPixelDensity.dashboardCorrected,
            );
            if (level != SoldierPixelationLevel.original) {
              final requests = motion == BaseCampSoldierMotion.breathing
                  ? profile.breathingRequests
                  : profile.regripRequests;
              expect(
                await tester.runAsync(
                  () => BaseCampSoldierPixelCache.instance
                      .prepareMotionRequests(requests, motion, level),
                ),
                isTrue,
              );
            }
            final boundaryKey = GlobalKey();
            await tester.pumpWidget(
              MaterialApp(
                home: RepaintBoundary(
                  key: boundaryKey,
                  child: ColoredBox(
                    color: const Color(0xff161b12),
                    child: SizedBox.fromSize(
                      size: viewport,
                      child: motion == BaseCampSoldierMotion.breathing
                          ? BaseCampBreathingSoldier(
                              dy: -.5,
                              pixelProfile: profile,
                            )
                          : BaseCampRifleRegripFrame(
                              frame: 3,
                              pixelProfile: profile,
                            ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            if (level == SoldierPixelationLevel.original) {
              await tester.pumpAndSettle();
            } else {
              expect(
                find.byKey(
                  ValueKey<String>(
                    'soldier-pixelated-${level.name}-'
                    '${motion == BaseCampSoldierMotion.breathing ? baseCampBreathingSoldierLowerAsset : baseCampRifleRegripAssets[3]}',
                  ),
                ),
                findsOneWidget,
              );
            }
            expect(tester.takeException(), isNull);
            if (_captureDirectory.isNotEmpty &&
                viewportEntry.key == 390 &&
                dpr == 3) {
              await tester.runAsync(() async {
                final boundary =
                    boundaryKey.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 1);
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final directory = Directory(_captureDirectory)
                  ..createSync(recursive: true);
                await File(
                  '${directory.path}/dashboard_${motion.name}_${level.name}.png',
                ).writeAsBytes(
                  data!.buffer.asUint8List(
                    data.offsetInBytes,
                    data.lengthInBytes,
                  ),
                );
                image.dispose();
              });
            }
          });
        }
      }
    }
  }
}
