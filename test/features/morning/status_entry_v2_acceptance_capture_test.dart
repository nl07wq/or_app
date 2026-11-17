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
import 'package:or_app/features/morning/widgets/base_camp_status_style.dart';
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
    await _loadFont(
      'MaterialIcons',
      'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
    await ShiftPresetPreferences.save(const <ShiftPreset>[
      ShiftPreset(
        id: 'early',
        name: '早番',
        startTime: '07:00',
        endTime: '18:00',
        breakTime: '01:00',
        order: 0,
      ),
      ShiftPreset(
        id: 'morning',
        name: '朝番',
        startTime: '09:00',
        endTime: '18:00',
        breakTime: '01:00',
        order: 1,
      ),
      ShiftPreset(
        id: 'middle',
        name: '中番',
        startTime: '11:00',
        endTime: '18:00',
        breakTime: '01:00',
        order: 2,
      ),
      ShiftPreset(
        id: 'late',
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
    (width: 390, negative: true, name: '390_inv'),
  ]) {
    testWidgets('captures STATUS ENTRY V2 acceptance ${config.name}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(config.width, 4300));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      DeviceSettingsController.instance.update(
        DeviceSettingsController.instance.value.copyWith(
          baseCampLcdNegative: config.negative,
        ),
      );

      final keys = <String, GlobalKey>{
        for (final name in <String>[
          'full',
          'body_editing',
          'body_completed',
          'recovery',
          'foot_editing_lv10',
          'foot_completed_lv10',
          'work',
        ])
          name: GlobalKey(),
      };
      final controllers = <TextEditingController>[];
      TextEditingController controller(String value) {
        final result = TextEditingController(text: value);
        controllers.add(result);
        return result;
      }

      final bodyEditWeight = controller('93.4');
      final bodyEditFat = controller('60.0');
      final bodyDoneWeight = controller('93.4');
      final bodyDoneFat = controller('31.9');
      final sleep = controller('7:15');
      final score = controller('100');
      final footEdit = controller('10');
      final footDone = controller('10');
      final workStart = controller('07:00');
      final workEnd = controller('18:00');
      final workBreak = controller('23:45');
      addTearDown(() {
        for (final item in controllers) {
          item.dispose();
        }
      });

      Widget evidence(String name, Widget child) => RepaintBoundary(
        key: keys[name],
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: child,
        ),
      );

      await tester.pumpWidget(
        _harness(
          config.width,
          RepaintBoundary(
            key: keys['full'],
            child: Column(
              children: <Widget>[
                evidence(
                  'body_editing',
                  BodyCard(
                    weightController: bodyEditWeight,
                    bodyFatController: bodyEditFat,
                    weightUnmeasured: false,
                    onWeightUnmeasured: () {},
                    onWeightMeasured: () {},
                    initiallyExpanded: true,
                  ),
                ),
                evidence(
                  'body_completed',
                  BodyCard(
                    weightController: bodyDoneWeight,
                    bodyFatController: bodyDoneFat,
                    weightUnmeasured: false,
                    onWeightUnmeasured: () {},
                    onWeightMeasured: () {},
                    initiallyExpanded: false,
                  ),
                ),
                evidence(
                  'recovery',
                  RecoveryCard(
                    sleepController: sleep,
                    sleepScoreController: score,
                    sleepType: SleepType.sleep,
                    onSleepTypeChanged: (_) {},
                    sleepTimeUnmeasured: false,
                    onSleepTimeUnmeasured: () {},
                    onSleepTimeMeasured: () {},
                    initiallyExpanded: true,
                  ),
                ),
                evidence(
                  'foot_editing_lv10',
                  FootCard(controller: footEdit, initiallyExpanded: true),
                ),
                evidence(
                  'foot_completed_lv10',
                  FootCard(controller: footDone, initiallyExpanded: false),
                ),
                evidence(
                  'work',
                  WorkCard(
                    workType: WorkType.work,
                    onChanged: (_) {},
                    startController: workStart,
                    endController: workEnd,
                    breakController: workBreak,
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

Widget _harness(double width, Widget child) => MaterialApp(
  theme: BaseCampRetroTheme.apply(ThemeData.light()),
  home: BaseCampPresentation(
    screen: BaseCampScreen.morning,
    child: BaseCampRetroTerminalScreen(
      screenKey: 'status-entry-v2-acceptance',
      child: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(size: Size(width, 4300)),
          child: BaseCampStatusEntrySurface(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _loadFont(String family, String asset) async {
  final bytes = File(asset).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  await loader.load();
}

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
