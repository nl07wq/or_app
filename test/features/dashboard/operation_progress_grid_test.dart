import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/engine/food_summary.dart';
import 'package:or_app/core/engine/training_summary.dart';
import 'package:or_app/core/models/daily_log_confirmation_status.dart';
import 'package:or_app/core/services/daily_log_confirmation_state.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/features/activity/models/activity_summary_state.dart';
import 'package:or_app/features/activity/models/activity_draft.dart';
import 'package:or_app/features/dashboard/dashboard_page.dart';
import 'package:or_app/features/food/models/food_summary_state.dart';
import 'package:or_app/features/morning/models/morning_fact.dart';
import 'package:or_app/features/morning/models/morning_fact_state.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/training/models/training_summary_state.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  setUp(() {
    appInitializationController.markReady();
    dailyLogConfirmationNotifier.value = DailyLogConfirmationStatus.unconfirmed(
      DateTime(2026, 7, 28),
    );
    morningFactNotifier.value = null;
    foodSummaryNotifier.value = null;
    activitySummaryNotifier.value = const ActivitySummary.empty();
    trainingSummaryNotifier.value = null;
    trainingCardioCaloriesNotifier.value = 0;
  });

  testWidgets('uses the approved two-column order and full-width ACTIVITY', (
    tester,
  ) async {
    await _pumpDashboard(tester, width: 800);

    expect(find.text('OPERATION PROGRESS'), findsOneWidget);
    expect(find.text('MORNING ROUTINE'), findsNothing);
    expect(find.text('Morning Routine'), findsNothing);

    final status = _tile('STATUS');
    final food = _tile('FOOD');
    final calories = _tile('CALORIES');
    final protein = _tile('PROTEIN');
    final water = _tile('WATER');
    final training = _tile('TRAINING');
    final activity = _tile('ACTIVITY');

    expect(tester.getTopLeft(status).dy, tester.getTopLeft(food).dy);
    expect(tester.getTopLeft(calories).dy, tester.getTopLeft(protein).dy);
    expect(tester.getTopLeft(water).dy, tester.getTopLeft(training).dy);
    expect(
      tester.getTopLeft(calories).dy,
      greaterThan(tester.getTopLeft(status).dy),
    );
    expect(
      tester.getTopLeft(water).dy,
      greaterThan(tester.getTopLeft(calories).dy),
    );
    expect(
      tester.getTopLeft(activity).dy,
      greaterThan(tester.getTopLeft(water).dy),
    );
    expect(
      tester.getSize(activity).width,
      closeTo(tester.getSize(status).width * 2 + 12, 0.1),
    );

    for (final label in _labels) {
      final progressFinder = find.descendant(
        of: _tile(label),
        matching: find.byType(LinearProgressIndicator),
      );
      expect(progressFinder, findsOneWidget);
      final indicator = tester.widget<LinearProgressIndicator>(progressFinder);
      expect(indicator.color, isNull);
      expect(indicator.backgroundColor, isNull);
    }
  });

  testWidgets('keeps existing values, targets, progress, and module states', (
    tester,
  ) async {
    morningFactNotifier.value = _morning();
    foodSummaryNotifier.value = const FoodSummary(
      calories: 1100,
      protein: 50,
      fat: 30,
      carbohydrates: 120,
      hydrationMl: 1750,
      mealCount: 2,
    );
    trainingSummaryNotifier.value = const TrainingSummary(
      completed: true,
      exerciseCount: 2,
      setCount: 6,
      duration: null,
      sessionName: null,
    );
    activitySummaryNotifier.value = const ActivitySummary(
      steps: 12345,
      measuredSteps: 12345,
      isRecorded: true,
    );

    await _pumpDashboard(tester, width: 800);

    _expectTileText('STATUS', '完了');
    _expectTileText('FOOD', '2 / 3');
    _expectTileText('CALORIES', '1100 / 2200 kcal');
    _expectTileText('PROTEIN', '50.0 / 100 g');
    _expectTileText('WATER', '1750 / 3500 ml');
    _expectTileText('TRAINING', '実施');
    _expectTileText('ACTIVITY', '12,345 steps');

    expect(_progress(tester, 'STATUS'), 1);
    expect(_progress(tester, 'FOOD'), closeTo(2 / 3, 1e-12));
    expect(_progress(tester, 'CALORIES'), 0.5);
    expect(_progress(tester, 'PROTEIN'), 0.5);
    expect(_progress(tester, 'WATER'), 0.5);
    expect(_progress(tester, 'TRAINING'), 1);
    expect(_progress(tester, 'ACTIVITY'), 0);
  });

  testWidgets('keeps missing STATUS, FOOD, TRAINING, and ACTIVITY contracts', (
    tester,
  ) async {
    await _pumpDashboard(tester, width: 800);

    _expectTileText('STATUS', '未完了');
    _expectTileText('FOOD', '0 / 3');
    _expectTileText('TRAINING', '未実施');
    _expectTileText('ACTIVITY', 'Not recorded');
    expect(_progress(tester, 'TRAINING'), 0);
    expect(_progress(tester, 'ACTIVITY'), 0);
  });

  testWidgets('does not complete ACTIVITY from a Draft alone', (tester) async {
    final database = FakeIndexedDbDatabase();
    final controller = AppInitializationController()..markReady();
    AppRepositoryRegistry.beginStartup(controller: controller);
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
    addTearDown(AppRepositoryRegistry.resetForTesting);

    final now = DateTime.utc(2020);
    await AppRepositoryRegistry.container.activityDrafts.save(
      ActivityDraft(
        localDate: '2026-07-28',
        measuredStepsInput: '4321',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await _pumpDashboard(tester, width: 800);

    _expectTileText('ACTIVITY', 'Not recorded');
    expect(_progress(tester, 'ACTIVITY'), 0);
  });

  testWidgets('uses two columns at a normal smartphone width', (tester) async {
    await _pumpDashboard(tester, width: 390);

    expect(
      tester.getTopLeft(_tile('STATUS')).dy,
      tester.getTopLeft(_tile('FOOD')).dy,
    );
    expect(
      tester.getTopLeft(_tile('WATER')).dy,
      tester.getTopLeft(_tile('TRAINING')).dy,
    );
    _expectProgressTilesFit(tester);
  });

  testWidgets('falls back to one column without overflow at 320 pixels', (
    tester,
  ) async {
    await _pumpDashboard(tester, width: 320);

    final positions = [
      for (final label in _labels) tester.getTopLeft(_tile(label)),
    ];
    for (var index = 1; index < positions.length; index++) {
      expect(positions[index].dx, positions.first.dx);
      expect(positions[index].dy, greaterThan(positions[index - 1].dy));
    }
    _expectProgressTilesFit(tester);
  });

  testWidgets('caps the grid width on PC displays', (tester) async {
    await _pumpDashboard(tester, width: 1440);

    expect(tester.getSize(_tile('ACTIVITY')).width, 800);
    expect(tester.getSize(_tile('STATUS')).width, 394);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps WATER tile tap behavior', (tester) async {
    await _pumpDashboard(tester, width: 800);

    await tester.tap(_tile('WATER'));
    await tester.pumpAndSettle();

    expect(find.text('QUICK WATER LOG'), findsOneWidget);
    expect(find.text('250 ml'), findsOneWidget);
    expect(find.text('Save Water'), findsOneWidget);
  });

  testWidgets('renders the grid without overflow in light and dark themes', (
    tester,
  ) async {
    await _pumpDashboard(tester, width: 390, theme: ThemeData.light());
    _expectProgressTilesFit(tester);

    await _pumpDashboard(tester, width: 390, theme: ThemeData.dark());
    _expectProgressTilesFit(tester);
  });
}

const _labels = [
  'STATUS',
  'FOOD',
  'CALORIES',
  'PROTEIN',
  'WATER',
  'TRAINING',
  'ACTIVITY',
];

Finder _tile(String label) => find.byKey(ValueKey('operation-progress-$label'));

void _expectTileText(String label, String text) {
  expect(
    find.descendant(of: _tile(label), matching: find.text(text)),
    findsOneWidget,
  );
}

double? _progress(WidgetTester tester, String label) {
  return tester
      .widget<LinearProgressIndicator>(
        find.descendant(
          of: _tile(label),
          matching: find.byType(LinearProgressIndicator),
        ),
      )
      .value;
}

void _expectProgressTilesFit(WidgetTester tester) {
  for (final label in _labels) {
    final tileRect = tester.getRect(_tile(label));
    final descendants = find.descendant(
      of: _tile(label),
      matching: find.byWidgetPredicate(
        (widget) => widget is Text || widget is LinearProgressIndicator,
      ),
    );

    for (final element in descendants.evaluate()) {
      final renderObject = element.renderObject;
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;
      final topLeft = renderObject.localToGlobal(Offset.zero);
      final rect = topLeft & renderObject.size;
      expect(rect.left, greaterThanOrEqualTo(tileRect.left));
      expect(rect.right, lessThanOrEqualTo(tileRect.right));
    }
  }
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required double width,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (!details.toString().contains('core/widgets/section_header.dart')) {
      originalOnError?.call(details);
    }
  };
  try {
    await tester.pumpWidget(
      MaterialApp(theme: theme, home: const DashboardPage()),
    );
    await tester.pump();
  } finally {
    FlutterError.onError = originalOnError;
  }
}

MorningFact _morning() {
  return MorningFact(
    date: DateTime(2026, 7, 28),
    weight: 90,
    bodyFat: 25,
    sleepDuration: const Duration(hours: 7),
    sleepScore: 80,
    workHours: 8,
    footPain: 1,
    medications: const [],
    freeNotes: null,
  );
}
