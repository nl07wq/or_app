import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/shift_preset.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/services/shift_preset_preferences.dart';
import 'package:or_app/features/morning/widgets/body_card.dart';
import 'package:or_app/features/morning/widgets/foot_card.dart';
import 'package:or_app/features/morning/widgets/recovery_card.dart';
import 'package:or_app/features/morning/widgets/work_card.dart';
import 'package:or_app/features/themes/base_camp/base_camp_presentation.dart';
import 'package:or_app/features/themes/base_camp/base_camp_retro_terminal.dart';
import 'package:or_app/features/themes/base_camp/base_camp_retro_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _captureDirectory = String.fromEnvironment('STATUS_CAPTURE_DIR');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFont('PressStart2P', 'assets/fonts/PressStart2P-Regular.ttf');
    await _loadFont('DotGothic16', 'assets/fonts/DotGothic16-Regular.ttf');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
    await ShiftPresetPreferences.save(const <ShiftPreset>[
      ShiftPreset(
        id: 'shift_early',
        name: '早番',
        startTime: '07:00',
        endTime: '18:00',
        breakTime: '01:00',
        order: 0,
      ),
      ShiftPreset(
        id: 'shift_morning',
        name: '朝番',
        startTime: '09:00',
        endTime: '18:00',
        breakTime: '01:00',
        order: 1,
      ),
      ShiftPreset(
        id: 'shift_middle',
        name: '中番',
        startTime: '11:00',
        endTime: '18:00',
        breakTime: '01:00',
        order: 2,
      ),
      ShiftPreset(
        id: 'shift_late',
        name: '遅番',
        startTime: '15:15',
        endTime: '00:15',
        breakTime: '01:00',
        order: 3,
      ),
    ]);
  });

  for (final config in <({double width, bool negative, String name})>[
    (width: 320, negative: false, name: '320_light'),
    (width: 320, negative: true, name: '320_inv'),
    (width: 375, negative: false, name: '375_light'),
    (width: 375, negative: true, name: '375_inv'),
    (width: 390, negative: false, name: '390_light'),
    (width: 390, negative: true, name: '390_inv'),
    (width: 430, negative: false, name: '430_light'),
    (width: 430, negative: true, name: '430_inv'),
  ]) {
    testWidgets('renders STATUS gauge evidence ${config.name}', (tester) async {
      await tester.binding.setSurfaceSize(Size(config.width, 2100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      DeviceSettingsController.instance.update(
        DeviceSettingsController.instance.value.copyWith(
          baseCampLcdNegative: config.negative,
        ),
      );

      final keys = <String, GlobalKey>{
        'full': GlobalKey(),
        'body_fat': GlobalKey(),
        'sleep_score': GlobalKey(),
        'foot_health': GlobalKey(),
        'work_shift': GlobalKey(),
      };
      final controllers = <TextEditingController>[
        TextEditingController(text: '94.2'),
        TextEditingController(text: '31.9'),
        TextEditingController(text: '7:00'),
        TextEditingController(text: '57'),
        TextEditingController(text: '5'),
        TextEditingController(text: '07:00'),
        TextEditingController(text: '18:00'),
        TextEditingController(text: '01:00'),
      ];
      addTearDown(() {
        for (final controller in controllers) {
          controller.dispose();
        }
      });

      await tester.pumpWidget(
        _harness(
          RepaintBoundary(
            key: keys['full'],
            child: Column(
              children: [
                RepaintBoundary(
                  key: keys['body_fat'],
                  child: BodyCard(
                    weightController: controllers[0],
                    bodyFatController: controllers[1],
                    weightUnmeasured: false,
                    onWeightUnmeasured: () {},
                    onWeightMeasured: () {},
                    initiallyExpanded: true,
                  ),
                ),
                const SizedBox(height: 12),
                RepaintBoundary(
                  key: keys['sleep_score'],
                  child: RecoveryCard(
                    sleepController: controllers[2],
                    sleepScoreController: controllers[3],
                    sleepType: SleepType.sleep,
                    onSleepTypeChanged: (_) {},
                    sleepTimeUnmeasured: false,
                    onSleepTimeUnmeasured: () {},
                    onSleepTimeMeasured: () {},
                    initiallyExpanded: true,
                  ),
                ),
                const SizedBox(height: 12),
                RepaintBoundary(
                  key: keys['foot_health'],
                  child: FootCard(
                    controller: controllers[4],
                    initiallyExpanded: true,
                  ),
                ),
                const SizedBox(height: 12),
                RepaintBoundary(
                  key: keys['work_shift'],
                  child: WorkCard(
                    workType: WorkType.work,
                    onChanged: (_) {},
                    startController: controllers[5],
                    endController: controllers[6],
                    breakController: controllers[7],
                    initiallyExpanded: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      if (_captureDirectory.isNotEmpty) {
        final directory = Directory(_captureDirectory)
          ..createSync(recursive: true);
        for (final entry in keys.entries) {
          await _capture(
            tester,
            entry.value,
            '${directory.path}/status_${entry.key}_${config.name}.png',
          );
        }
      }
    });
  }
}

Future<void> _loadFont(String family, String asset) async {
  final bytes = File(asset).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  await loader.load();
}

Widget _harness(Widget child) => MaterialApp(
  theme: BaseCampRetroTheme.apply(ThemeData.light()),
  home: BaseCampPresentation(
    screen: BaseCampScreen.morning,
    child: BaseCampRetroTerminalScreen(
      screenKey: 'status-gauge-shift-capture',
      child: Scaffold(
        body: BaseCampTerminalDisplay(
          margin: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ),
      ),
    ),
  ),
);

Future<void> _capture(
  WidgetTester tester,
  GlobalKey key,
  String outputPath,
) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(outputPath).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
