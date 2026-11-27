import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/widgets/dashboard_glass_card.dart';
import 'package:or_app/core/widgets/operation_button.dart';
import 'package:or_app/core/widgets/operation_card.dart';
import 'package:or_app/core/widgets/operation_text_field.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/features/morning/widgets/body_card.dart';
import 'package:or_app/features/morning/widgets/recovery_card.dart';
import 'package:or_app/features/themes/base_camp/base_camp_dashboard_page.dart'
    show BaseCampLcdGrainPainter;
import 'package:or_app/features/themes/base_camp/base_camp_presentation.dart';
import 'package:or_app/features/themes/base_camp/base_camp_retro_terminal.dart';
import 'package:or_app/features/themes/base_camp/base_camp_retro_theme.dart';

void main() {
  setUp(() {
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
  });

  for (final width in <double>[320, 375, 390, 430]) {
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
      final housingSize = tester.getSize(
        find.byKey(const ValueKey('base-camp-terminal-housing')),
      );
      final displaySize = tester.getSize(
        find.byKey(const ValueKey('base-camp-terminal-lcd-surface')),
      );
      expect(displaySize.width, lessThan(housingSize.width));
      expect(displaySize.height, lessThan(housingSize.height));
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
    expect(
      Theme.of(
        tester.element(find.text('STATUS ENTRY')),
      ).appBarTheme.foregroundColor?.toARGB32(),
      0xffaeb894,
    );
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
    expect(
      Theme.of(
        tester.element(find.text('STATUS ENTRY')),
      ).appBarTheme.foregroundColor?.toARGB32(),
      0xffaeb894,
    );
    expect((grain.painter! as BaseCampLcdGrainPainter).negative, isTrue);
  });

  testWidgets('instrument LCD owns the approved bright clipped grid', (
    tester,
  ) async {
    await tester.pumpWidget(
      _baseCampHarness(
        child: const Scaffold(
          body: Center(
            child: BaseCampInstrumentLcd(child: Text('COMMAND CENTER READOUT')),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(BaseCampInstrumentLcd.lightSurface.toARGB32(), 0xffb9c8a0);
    expect(BaseCampInstrumentLcd.lightInk.toARGB32(), 0xff263c29);
    expect(BaseCampInstrumentLcd.lightSecondaryInk.toARGB32(), 0xff526c4b);
    expect(BaseCampInstrumentLcd.lightRecess.toARGB32(), 0xff4d6148);
    expect(BaseCampInstrumentLcd.lightOuterBorder.toARGB32(), 0xff263a29);
    expect(
      _contrastRatio(
        BaseCampInstrumentLcd.lightInk,
        BaseCampInstrumentLcd.lightSurface,
      ),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(const Color(0xfff0f4df), const Color(0xff526c4b)),
      greaterThanOrEqualTo(4.5),
    );
    final grid = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('base-camp-instrument-lcd-grid')),
    );
    expect(grid.painter, isA<BaseCampInstrumentGridPainter>());
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('base-camp-instrument-lcd-grid')),
        matching: find.byType(ClipRRect),
      ),
      findsWidgets,
    );
  });

  for (final negative in <bool>[false, true]) {
    testWidgets(
      'shared controls are opaque classic terminal surfaces when INV=$negative',
      (tester) async {
        DeviceSettingsController.instance.update(
          DeviceSettingsController.instance.value.copyWith(
            baseCampLcdNegative: negative,
          ),
        );
        final controller = TextEditingController(text: '500 / 2900 ml');
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _baseCampHarness(
            child: Scaffold(
              body: ListView(
                children: [
                  const DashboardGlassCard(
                    child: Text('OPAQUE TERMINAL PANEL'),
                  ),
                  OperationTextField(
                    key: const ValueKey('terminal-input'),
                    controller: controller,
                    label: 'WATER',
                    glass: true,
                  ),
                  const OperationButton(
                    key: ValueKey('terminal-disabled-button'),
                    text: 'DISABLED',
                    onPressed: null,
                    dashboardGlass: true,
                    frostedGradient: true,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        final context = tester.element(find.text('OPAQUE TERMINAL PANEL'));
        final theme = Theme.of(context);
        final surface = theme.extension<OperationSurfaceTheme>();
        expect(surface?.useClassicTerminal, isTrue);
        expect(theme.cardColor.a, 1);

        final card = tester.widget<Card>(find.byType(Card).first);
        expect(card.color?.a, 1);
        expect(card.elevation, 0);
        expect(card.shadowColor, Colors.transparent);

        final field = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const ValueKey('terminal-input')),
            matching: find.byType(TextField),
          ),
        );
        expect(field.decoration?.filled, isTrue);
        expect(field.decoration?.fillColor?.a, 1);

        final button = tester.widget<ElevatedButton>(
          find.descendant(
            of: find.byKey(const ValueKey('terminal-disabled-button')),
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(button.style?.backgroundColor?.resolve(<WidgetState>{})?.a, 1);
        expect(
          button.style?.backgroundColor?.resolve(<WidgetState>{
            WidgetState.disabled,
          })?.a,
          1,
        );
        expect(find.byType(DashboardGlassCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

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

  testWidgets('STATUS keeps its picker controls in classic terminal mode', (
    tester,
  ) async {
    final weight = TextEditingController(text: '72.5');
    final bodyFat = TextEditingController(text: '18.0');
    final sleep = TextEditingController(text: '7:30');
    final sleepScore = TextEditingController(text: '82');
    addTearDown(() {
      weight.dispose();
      bodyFat.dispose();
      sleep.dispose();
      sleepScore.dispose();
    });
    await tester.pumpWidget(
      _baseCampHarness(
        child: Scaffold(
          body: TickerMode(
            enabled: false,
            child: ListView(
              children: [
                BodyCard(
                  weightController: weight,
                  bodyFatController: bodyFat,
                  weightUnmeasured: false,
                  onWeightUnmeasured: () {},
                  onWeightMeasured: () {},
                  initiallyExpanded: true,
                ),
                RecoveryCard(
                  sleepController: sleep,
                  sleepScoreController: sleepScore,
                  sleepType: SleepType.sleep,
                  onSleepTypeChanged: (_) {},
                  sleepTimeUnmeasured: false,
                  onSleepTimeUnmeasured: () {},
                  onSleepTimeMeasured: () {},
                  initiallyExpanded: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('status-weight-radio-tuner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('status-body-fat-segment-meter')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('status-weight-hud')), findsNothing);
    expect(find.byKey(const ValueKey('status-body-fat-ring')), findsNothing);
    expect(
      find.byKey(const ValueKey('status-sleep-duration-picker')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('status-sleep-score-hud-sleep')),
      findsOneWidget,
    );
    expect(find.byType(OperationTextField), findsNothing);
    for (final label in const <String>['未計測', '睡眠', '仮眠']) {
      final texts = tester
          .widgetList<Text>(find.text(label))
          .where((text) => text.style?.fontFamily == 'DotGothic16');
      expect(texts, isNotEmpty, reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('route housing does not own a full-page LCD grid', (
    tester,
  ) async {
    await tester.pumpWidget(_baseCampHarness());
    await tester.pump();

    final panel = tester.widget<BaseCampRetroTerminalPanel>(
      find.byType(BaseCampRetroTerminalPanel),
    );
    expect(panel.child, isNot(isA<BaseCampLcdSurface>()));
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('base-camp-terminal-lcd-grid')),
        matching: find.byType(BaseCampLcdSurface),
      ),
      findsOneWidget,
    );
  });

  test('all direct BASE CAMP routes use the shared presentation layer', () {
    const files = <String, String>{
      'lib/features/schedule/pages/calendar_page.dart': 'calendar',
      'lib/features/morning/morning_history_page.dart': 'status-record',
      'lib/features/morning/morning_fact_page.dart': 'status-entry',
      'lib/features/food/food_entry_page.dart': 'food-entry',
      'lib/features/training/training_entry_page.dart': 'training',
      'lib/features/activity/activity_entry_page.dart': 'activity-entry',
      'lib/features/activity/activity_history_page.dart': 'activity-record',
      'lib/features/command_center/pages/command_center_page.dart':
          'command-center',
      'lib/features/command_center/widgets/brief_debrief_page.dart':
          'daily-brief-detail',
      'lib/features/body_history/pages/data_center_history_page.dart':
          'data-center-history',
      'lib/features/daily_aggregate/pages/daily_aggregate_records_page.dart':
          'daily-aggregate-records',
      'lib/features/periodic_report/pages/periodic_report_page.dart':
          'periodic-report',
      'lib/features/report_sync/pages/report_sync_exchange_page.dart':
          'report-sync-\${exchangeType.name}',
      'lib/features/reminders/pages/reminders_page.dart': 'reminders',
      'lib/features/weather/weather_settings_page.dart': 'weather-settings',
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

  test(
    'FOOD, TRAINING and HISTORY descendants use shared terminal scaffolds',
    () {
      const coverage = <String, String>{
        'lib/features/food/daily_nutrition_analysis_page.dart':
            'FoodFeatureScaffold(',
        'lib/features/food/food_catalog_page.dart': 'FoodFeatureScaffold(',
        'lib/features/food/food_edit_page.dart': 'FoodFeatureScaffold(',
        'lib/features/food/food_history_page.dart': 'FoodFeatureScaffold(',
        'lib/features/food/food_meal_master_page.dart': 'FoodFeatureScaffold(',
        'lib/features/food/food_page.dart': 'FoodFeatureScaffold(',
        'lib/features/food/food_recipe_page.dart': 'FoodFeatureScaffold(',
        'lib/features/food/meal_analysis_page.dart': 'FoodFeatureScaffold(',
        'lib/features/food/widgets/food_manual_nutrition_crop.dart':
            'FoodFeatureScaffold(',
        'lib/features/training/training_detail_page.dart':
            'TrainingKineticScaffold(',
        'lib/features/training/training_history_page.dart':
            'TrainingKineticScaffold(',
        'lib/features/training/training_plan_import_page.dart':
            'TrainingKineticScaffold(',
        'lib/features/training/training_plan_page.dart':
            'TrainingKineticScaffold(',
        'lib/features/training_analysis/pages/training_analysis_page.dart':
            'TrainingKineticScaffold(',
        'lib/features/body_history/pages/body_history_page.dart':
            'HistoryFeatureScaffold(',
        'lib/features/nutrition_history/pages/nutrition_history_page.dart':
            'HistoryFeatureScaffold(',
        'lib/features/digestive_history/pages/digestive_history_page.dart':
            'HistoryFeatureScaffold(',
        'lib/features/activity_history/pages/activity_history_page.dart':
            'HistoryFeatureScaffold(',
        'lib/features/sleep_history/pages/sleep_history_page.dart':
            'HistoryFeatureScaffold(',
        'lib/features/training/data_center_training_history_page.dart':
            'HistoryFeatureScaffold(',
      };
      for (final entry in coverage.entries) {
        expect(
          File(entry.key).readAsStringSync(),
          contains(entry.value),
          reason: entry.key,
        );
      }
    },
  );

  test('nested modal routes retain terminal coverage', () {
    const coverage = <String, List<String>>{
      'lib/features/schedule/pages/calendar_page.dart': [
        "screenKey: 'calendar'",
        "screenKey: 'calendar-schedule-editor'",
      ],
      'lib/features/reminders/pages/reminders_page.dart': [
        "screenKey: 'reminders'",
        "screenKey: 'reminder-editor'",
      ],
      'lib/features/daily_aggregate/pages/daily_aggregate_records_page.dart': [
        "screenKey: 'daily-aggregate-records'",
        "screenKey: 'daily-aggregate-detail'",
      ],
      'lib/features/report_sync/pages/report_sync_exchange_page.dart': [
        "screenKey: 'report-sync-record-archive'",
        "screenKey: 'report-sync-record-detail'",
      ],
      'lib/features/command_center/widgets/brief_debrief_page.dart': [
        "screenKey: 'daily-brief-detail'",
        "screenKey: 'daily-debrief-detail'",
        "screenKey: 'daily-brief-archive'",
        "screenKey: 'daily-debrief-archive'",
        "screenKey: 'daily-brief-revision'",
      ],
    };
    for (final entry in coverage.entries) {
      final source = File(entry.key).readAsStringSync();
      for (final marker in entry.value) {
        expect(source, contains(marker), reason: '${entry.key}: $marker');
      }
    }
  });

  test(
    'protected PROFILE ABOUT SYSTEM sources do not gain terminal wrappers',
    () {
      for (final path in const <String>[
        'lib/features/system/pages/profile_page.dart',
        'lib/features/system/pages/about_page.dart',
        'lib/features/system/pages/system_page.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          isNot(contains('BaseCampRetroTerminalScreen(')),
          reason: path,
        );
      }
    },
  );
}

double _contrastRatio(Color foreground, Color background) {
  double luminance(Color color) {
    double channel(int value) {
      final normalized = value / 255;
      return normalized <= .04045
          ? normalized / 12.92
          : math.pow((normalized + .055) / 1.055, 2.4).toDouble();
    }

    final argb = color.toARGB32();
    return .2126 * channel((argb >> 16) & 0xff) +
        .7152 * channel((argb >> 8) & 0xff) +
        .0722 * channel(argb & 0xff);
  }

  final first = luminance(foreground);
  final second = luminance(background);
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + .05) / (darker + .05);
}

Widget _baseCampHarness({Widget? child}) => MaterialApp(
  theme: BaseCampRetroTheme.apply(ThemeData.light()),
  home: BaseCampPresentation(
    screen: BaseCampScreen.system,
    child: BaseCampRetroTerminalScreen(
      screenKey: 'contract-test',
      child:
          child ??
          Scaffold(
            appBar: AppBar(title: const Text('STATUS ENTRY')),
            body: BaseCampTerminalDisplay(
              margin: const EdgeInsets.all(8),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: const <Widget>[
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('BODY'),
                    ),
                  ),
                  TextField(
                    decoration: InputDecoration(labelText: 'WEIGHT kg'),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton(onPressed: null, child: Text('SAVE')),
                ],
              ),
            ),
          ),
    ),
  ),
);
