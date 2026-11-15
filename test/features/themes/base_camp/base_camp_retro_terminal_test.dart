import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/themes/base_camp/base_camp_dashboard_page.dart'
    show BaseCampLcdGrainPainter;
import 'package:or_app/features/themes/base_camp/base_camp_presentation.dart';
import 'package:or_app/features/themes/base_camp/base_camp_retro_terminal.dart';
import 'package:or_app/features/themes/base_camp/base_camp_retro_theme.dart';

void main() {
  setUp(() {
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
  });

  for (final width in <double>[320, 375, 390]) {
    testWidgets('terminal presentation fits $width logical pixels', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_baseCampHarness());
      await tester.pump();

      expect(
        find.byKey(const ValueKey('base-camp-retro-terminal-contract-test')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('base-camp-terminal-lcd-grid')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Dashboard INV state reactively drives the shared LCD palette', (
    tester,
  ) async {
    await tester.pumpWidget(_baseCampHarness());
    await tester.pump();

    var scope = tester.widget<BaseCampTerminalPaletteScope>(
      find.byType(BaseCampTerminalPaletteScope),
    );
    var grain = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('base-camp-terminal-lcd-grid')),
    );
    expect(scope.palette.negative, isFalse);
    expect(scope.palette.background.toARGB32(), 0xffaeb894);
    expect(scope.palette.primaryText.toARGB32(), 0xff273326);
    expect((grain.painter! as BaseCampLcdGrainPainter).negative, isFalse);

    DeviceSettingsController.instance.update(
      DeviceSettingsController.instance.value.copyWith(
        baseCampLcdNegative: true,
      ),
    );
    await tester.pump();

    scope = tester.widget<BaseCampTerminalPaletteScope>(
      find.byType(BaseCampTerminalPaletteScope),
    );
    grain = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('base-camp-terminal-lcd-grid')),
    );
    expect(scope.palette.negative, isTrue);
    expect(scope.palette.background.toARGB32(), 0xff273326);
    expect(scope.palette.primaryText.toARGB32(), 0xffaeb894);
    expect(scope.palette.auxiliaryText.toARGB32(), 0xff788a66);
    expect((grain.painter! as BaseCampLcdGrainPainter).negative, isTrue);
  });

  testWidgets('STANDARD retains its original widget tree and Theme', (
    tester,
  ) async {
    const original = ColoredBox(
      key: ValueKey('standard-original'),
      color: Color(0xff123456),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: BaseCampRetroTerminalScreen(
          screenKey: 'standard',
          child: original,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('standard-original')), findsOneWidget);
    expect(find.byType(BaseCampTerminalPaletteScope), findsNothing);
    expect(
      find.byKey(const ValueKey('base-camp-terminal-lcd-grid')),
      findsNothing,
    );
  });

  test('all six approved pages use the shared presentation layer', () {
    const files = <String, String>{
      'lib/features/schedule/pages/calendar_page.dart': 'calendar',
      'lib/features/morning/morning_history_page.dart': 'status-record',
      'lib/features/morning/morning_fact_page.dart': 'status-entry',
      'lib/features/food/food_entry_page.dart': 'food-entry',
      'lib/features/training/training_entry_page.dart': 'training',
      'lib/features/activity/activity_entry_page.dart': 'activity-entry',
    };
    for (final entry in files.entries) {
      final source = File(entry.key).readAsStringSync();
      expect(
        source,
        contains('BaseCampRetroTerminalScreen('),
        reason: entry.key,
      );
      expect(
        source,
        contains("screenKey: '${entry.value}'"),
        reason: entry.key,
      );
    }
  });
}

Widget _baseCampHarness() => MaterialApp(
  theme: BaseCampRetroTheme.apply(ThemeData.light()),
  home: BaseCampPresentation(
    screen: BaseCampScreen.system,
    child: BaseCampRetroTerminalScreen(
      screenKey: 'contract-test',
      child: Scaffold(
        appBar: AppBar(title: const Text('STATUS ENTRY')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const <Widget>[
            Card(
              child: Padding(padding: EdgeInsets.all(12), child: Text('BODY')),
            ),
            TextField(decoration: InputDecoration(labelText: 'WEIGHT kg')),
            SizedBox(height: 12),
            ElevatedButton(onPressed: null, child: Text('SAVE')),
          ],
        ),
      ),
    ),
  ),
);
