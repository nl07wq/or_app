import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/activity_summary.dart';
import 'package:or_app/core/engine/food_summary.dart';
import 'package:or_app/core/models/bowel_movement_record.dart';
import 'package:or_app/core/services/daily_log_confirmation_service.dart';
import 'package:or_app/core/services/daily_log_confirmation_validation.dart';
import 'package:or_app/features/command_center/widgets/brief_debrief_page.dart';
import 'package:or_app/features/morning/models/morning_fact.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/report_sync/pages/report_sync_exchange_page.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  tearDown(AppRepositoryRegistry.resetForTesting);

  testWidgets(
    'current eligible date prepares once and opens report sync directly',
    (tester) async {
      final database = FakeIndexedDbDatabase();
      final container = AppRepositoryContainer.indexedDb(database);
      await container.operationState.createInitial(
        OperationLocalDate.parse('2026-08-12'),
      );
      AppRepositoryRegistry.install(container);
      final snapshot = _snapshot();
      var preparationCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BriefDebriefPage(
              dailyLogSourceLoader: (_) async => snapshot,
              prepareDailyDebrief: (date, _) async {
                expect(date, '2026-08-12');
                preparationCount++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('DAILY DEBRIEF').first);
      await tester.pumpAndSettle();

      expect(find.text('2026-08-12'), findsOneWidget);
      expect(find.text('CREATE DAILY DEBRIEF'), findsOneWidget);
      await tester.tap(find.text('CREATE DAILY DEBRIEF'));
      await tester.pumpAndSettle();

      expect(preparationCount, 1);
      expect(find.byType(ReportSyncExchangePage), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'DAILY REVIEW'), findsNothing);
      expect(find.text('CONFIRM'), findsNothing);
    },
  );
}

DailyLogSourceSnapshot _snapshot() {
  final morning = MorningFact(
    date: DateTime(2026, 8, 12),
    weight: 80,
    bodyFat: 20,
    sleepDuration: const Duration(hours: 8),
    sleepScore: 80,
    workHours: 8,
    footPain: 0,
    medications: const [],
    freeNotes: null,
  );
  const food = FoodSummary(
    calories: 1800,
    protein: 100,
    fat: 60,
    carbohydrates: 200,
    hydrationMl: 2000,
    mealCount: 3,
  );
  final activity = ActivitySummary(
    steps: 5000,
    measuredSteps: 5000,
    isRecorded: true,
    bowelMovement: BowelMovementRecord.recorded(amount: 1, shape: 2),
    calculationBasis: const ActivityCalculationBasis(
      rawSteps: 5000,
      currentCarryOver: 0,
      previousCarryOverDeduction: 0,
      officialSteps: 5000,
    ),
  );
  final validation = DailyLogConfirmationValidation.validate(
    morning: morning,
    food: food,
    activity: activity,
    training: null,
  );
  return DailyLogSourceSnapshot(
    morning: morning,
    food: food,
    activity: activity,
    training: null,
    validation: validation,
  );
}
