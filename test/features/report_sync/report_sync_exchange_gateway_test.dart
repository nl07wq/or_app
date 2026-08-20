import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/daily_log_confirmation.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/food/repository/food_meal_id_generator.dart';
import 'package:or_app/features/report_sync/models/report_sync_envelope.dart';
import 'package:or_app/features/report_sync/models/report_sync_issue.dart';
import 'package:or_app/features/report_sync/models/morning_brief_record.dart';
import 'package:or_app/features/report_sync/models/status_report_sync_source.dart';
import 'package:or_app/features/report_sync/services/report_sync_exchange_gateway.dart';
import 'package:or_app/features/report_sync/services/report_sync_persistence_service.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/training/repository/training_record_id_generator.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  final now = DateTime.utc(2026, 8, 3, 9);

  test(
    'production gateway prepares all active exchanges from formal facts',
    () async {
      final container = AppRepositoryContainer.indexedDb(
        FakeIndexedDbDatabase(),
      );
      final initial = await container.operationState.createInitial(
        OperationLocalDate.parse('2026-08-03'),
      );
      await container.operationState.save(
        initial.copyWith(
          lastFinalizedDate: OperationLocalDate.parse('2026-08-02'),
          revision: initial.revision + 1,
          updatedAt: initial.updatedAt.add(const Duration(microseconds: 1)),
        ),
        expectedRevision: initial.revision,
      );
      await container.status.save(_status('2026-08-03'));
      await container.training.saveNewV2(TrainingSessionV2(date: '2026-08-03'));
      await container.food.save(
        const MealData(
          date: '2026-08-03',
          mealType: 'Breakfast',
          items: [
            FoodItem(
              name: 'Oats',
              calories: 100,
              protein: 4,
              fat: 2,
              carbohydrate: 18,
            ),
          ],
          memo: '',
          id: 'breakfast-2026-08-03',
        ),
      );
      await container.confirmation.save(
        DailyLogConfirmation(
          date: DateTime(2026, 8, 2),
          confirmedAt: now,
          morning: null,
          food: null,
          activity: null,
          training: null,
        ),
      );
      final gateway = ProductionReportSyncExchangeGateway(
        container: container,
        clock: () => now,
      );

      for (final type in ReportSyncExchangeType.values) {
        final prepared = await gateway.prepareRequest(type);
        if (type == ReportSyncExchangeType.dailyDebrief) {
          expect(prepared.isReady, isFalse);
          continue;
        }
        expect(prepared.isReady, isTrue, reason: type.stableId);
        expect(prepared.operationDate, '2026-08-03');
        if (type == ReportSyncExchangeType.training ||
            type == ReportSyncExchangeType.food) {
          expect(prepared.sourceText, isNull, reason: type.stableId);
        } else {
          expect(prepared.sourceText, isNotNull, reason: type.stableId);
          expect(prepared.sourceText, startsWith('OPERATION REBOOT\n'));
          expect(prepared.sourceText, isNot(startsWith('{')));
        }
        if (type == ReportSyncExchangeType.morningBrief) {
          expect(prepared.statusLabel, 'READY');
          expect(prepared.statusSourceExport, isNotNull);
        }
      }
      final morning = await gateway.prepareRequest(
        ReportSyncExchangeType.morningBrief,
      );
      final morningSource = morning.statusSourceExport!.plainText;
      final morningPrompt = gateway.instruction(
        ReportSyncExchangeType.morningBrief,
        morning,
      );
      expect(morningPrompt, contains('正式なDAILY BRIEF'));
      expect(morningPrompt, isNot(contains('MORNING BRIEF')));
      expect(morningPrompt, contains('SOURCE DATA START'));
      expect(morningPrompt, contains('SOURCE DATA END'));
      expect(morningPrompt, contains(morningSource));
      expect(morningPrompt.split(morningSource), hasLength(2));
      expect(morningPrompt, contains('RECENT CONTEXT JSON'));
      expect(morningPrompt, contains('"windowStart": "2026-07-27"'));
      expect(morningPrompt, contains('"windowEnd": "2026-08-02"'));
      expect(
        morningPrompt,
        contains('The target-date STATUS is the CURRENT FACT'),
      );
      expect(morningPrompt, contains('2330 becomes 2,330'));
      expect(morningPrompt, contains('229 minutes is 3:49'));
      expect(morningPrompt, contains('"schemaVersion": "2.0"'));
      expect(morningPrompt, contains('"packageDigest": null'));
      expect(morningPrompt, isNot(contains('"actionId":')));
      expect(
        gateway.instruction(
          ReportSyncExchangeType.training,
          await gateway.prepareRequest(ReportSyncExchangeType.training),
        ),
        contains('Training Record'),
      );
      expect(await container.reportSyncHistory.list(), isEmpty);
    },
  );

  test(
    'Morning Brief Schema 2 imports MB and record atomically with read-back',
    () async {
      final database = FakeIndexedDbDatabase();
      final container = AppRepositoryContainer.indexedDb(database);
      await container.operationState.createInitial(
        OperationLocalDate.parse('2026-08-03'),
      );
      await container.status.save(_status('2026-08-03'));
      final gateway = ProductionReportSyncExchangeGateway(
        container: container,
        clock: () => now,
      );
      final preparation = await gateway.prepareRequest(
        ReportSyncExchangeType.morningBrief,
        targetDate: '2026-08-03',
      );
      final response = container.reportSyncCodec.create(
        direction: ReportSyncDirection.response,
        schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
        exchangeType: ReportSyncExchangeType.morningBrief,
        exchangeId: 'morning-v2-success',
        operationDate: '2026-08-03',
        createdAt: now,
        payload: _morningBriefPayload(preparation.statusSourceExport!),
      );
      final preview = await gateway.previewResponse(
        ReportSyncExchangeType.morningBrief,
        container.reportSyncCodec.encode(response),
        targetDate: '2026-08-03',
      );
      expect(preview.disposition, ReportSyncDisposition.create);
      expect(preview.morningBriefSourceDigestMatches, isTrue);

      final transactionsBeforeApply = database.transactionCount;
      final result = await gateway.apply(preview);
      expect(result.readBackVerified, isTrue);
      expect(database.transactionCount, transactionsBeforeApply + 1);
      final saved = await container.morningBriefs.readByLocalDate('2026-08-03');
      expect(saved?.recordVersion, MorningBriefRecord.currentRecordVersion);
      expect(saved?.sourceDigest, preparation.statusSourceExport!.sourceDigest);
      expect(saved?.actions.single.actionId, '2026-08-03:action:1');
      expect(
        await container.reportSyncHistory.readById('morning-v2-success'),
        isNotNull,
      );

      final noChange = await gateway.previewResponse(
        ReportSyncExchangeType.morningBrief,
        container.reportSyncCodec.encode(response),
        targetDate: '2026-08-03',
      );
      expect(noChange.disposition, ReportSyncDisposition.noChanges);
      expect(noChange.canApply, isFalse);

      final revisedPayload = _morningBriefPayload(
        preparation.statusSourceExport!,
      );
      final revisedContent = Map<String, Object?>.from(
        revisedPayload['content'] as Map,
      );
      revisedContent['commanderIntent'] = '修正版の意図です。';
      revisedPayload['content'] = revisedContent;
      final revisedResponse = container.reportSyncCodec.create(
        direction: ReportSyncDirection.response,
        schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
        exchangeType: ReportSyncExchangeType.morningBrief,
        exchangeId: 'morning-v2-revision-2',
        operationDate: '2026-08-03',
        createdAt: now.add(const Duration(minutes: 1)),
        payload: revisedPayload,
      );
      final revisionPreview = await gateway.previewResponse(
        ReportSyncExchangeType.morningBrief,
        container.reportSyncCodec.encode(revisedResponse),
        targetDate: '2026-08-03',
      );
      expect(revisionPreview.disposition, ReportSyncDisposition.create);
      await gateway.apply(revisionPreview);
      final revised = await container.morningBriefs.readByLocalDate(
        '2026-08-03',
      );
      expect(revised?.revision, 2);
      expect(revised?.commanderIntent, '修正版の意図です。');
      expect(revised?.previousRevisions, hasLength(1));
      expect(
        revised?.previousRevisions.single.record.commanderIntent,
        saved?.commanderIntent,
      );
    },
  );

  test('Morning Brief read-back failure rolls back MB and record', () async {
    final database = FakeIndexedDbDatabase();
    final container = AppRepositoryContainer.indexedDb(database);
    await container.operationState.createInitial(
      OperationLocalDate.parse('2026-08-03'),
    );
    await container.status.save(_status('2026-08-03'));
    final gateway = ProductionReportSyncExchangeGateway(
      container: container,
      clock: () => now,
    );
    final preparation = await gateway.prepareRequest(
      ReportSyncExchangeType.morningBrief,
      targetDate: '2026-08-03',
    );
    final response = container.reportSyncCodec.create(
      direction: ReportSyncDirection.response,
      schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
      exchangeType: ReportSyncExchangeType.morningBrief,
      exchangeId: 'morning-v2-rollback',
      operationDate: '2026-08-03',
      createdAt: now,
      payload: _morningBriefPayload(preparation.statusSourceExport!),
    );
    final preview = await gateway.previewResponse(
      ReportSyncExchangeType.morningBrief,
      container.reportSyncCodec.encode(response),
      targetDate: '2026-08-03',
    );
    database.failNextReadAfterPutForStore =
        IndexedDbStoreNames.morningBriefRecords;

    await expectLater(
      gateway.apply(preview),
      throwsA(isA<ReportSyncImportFailure>()),
    );
    expect(await container.morningBriefs.readByLocalDate('2026-08-03'), isNull);
    expect(
      await container.reportSyncHistory.readById('morning-v2-rollback'),
      isNull,
    );
  });

  test(
    'Morning Brief blocks a mismatched current STATUS source digest',
    () async {
      final database = FakeIndexedDbDatabase();
      final container = AppRepositoryContainer.indexedDb(database);
      await container.operationState.createInitial(
        OperationLocalDate.parse('2026-08-03'),
      );
      await container.status.save(_status('2026-08-03'));
      final gateway = ProductionReportSyncExchangeGateway(
        container: container,
        clock: () => now,
      );
      final preparation = await gateway.prepareRequest(
        ReportSyncExchangeType.morningBrief,
        targetDate: '2026-08-03',
      );
      final payload = _morningBriefPayload(preparation.statusSourceExport!);
      payload['source'] = {
        ...Map<String, Object?>.from(payload['source'] as Map),
        'sourceDigest':
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      };
      final response = container.reportSyncCodec.create(
        direction: ReportSyncDirection.response,
        schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
        exchangeType: ReportSyncExchangeType.morningBrief,
        exchangeId: 'morning-v2-source-mismatch',
        operationDate: '2026-08-03',
        createdAt: now,
        payload: payload,
      );

      await expectLater(
        gateway.previewResponse(
          ReportSyncExchangeType.morningBrief,
          container.reportSyncCodec.encode(response),
          targetDate: '2026-08-03',
        ),
        throwsA(
          isA<ReportSyncException>().having(
            (error) => error.validationError?.jsonPath,
            'jsonPath',
            r'$.payload.source.sourceDigest',
          ),
        ),
      );
    },
  );

  test('training and food accept an explicit historical target date', () async {
    final container = AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase());
    await container.operationState.createInitial(
      OperationLocalDate.parse('2026-08-03'),
    );
    final gateway = ProductionReportSyncExchangeGateway(container: container);

    for (final type in const [
      ReportSyncExchangeType.training,
      ReportSyncExchangeType.food,
    ]) {
      final prepared = await gateway.prepareRequest(
        type,
        targetDate: '2026-07-01',
      );
      expect(prepared.operationDate, '2026-07-01');
      expect(prepared.sourceText, isNull);
      expect(gateway.instruction(type, prepared), contains('2026-07-01'));
    }
  });

  test(
    'prompt readiness uses operation date rather than local record presence',
    () async {
      final container = AppRepositoryContainer.indexedDb(
        FakeIndexedDbDatabase(),
      );
      await container.operationState.createInitial(
        OperationLocalDate.parse('2026-08-03'),
      );
      final gateway = ProductionReportSyncExchangeGateway(
        container: container,
        clock: () => now,
      );

      final training = await gateway.prepareRequest(
        ReportSyncExchangeType.training,
      );
      expect(training.isReady, isTrue);
      expect(training.sourceText, isNull);

      final food = await gateway.prepareRequest(ReportSyncExchangeType.food);
      expect(food.isReady, isTrue);
      expect(food.sourceText, isNull);

      final morning = await gateway.prepareRequest(
        ReportSyncExchangeType.morningBrief,
      );
      expect(morning.isReady, isTrue);
      expect(morning.sourceText, isNull);
      expect(morning.statusLabel, 'MISSING');
      expect(morning.blockingReason, '対象日のSTATUSがありません。');
    },
  );

  test(
    'food response previews, applies atomically, and becomes no changes',
    () async {
      final runtimeNow = DateTime.now().toUtc();
      final container = AppRepositoryContainer.indexedDb(
        FakeIndexedDbDatabase(),
      );
      await container.operationState.createInitial(
        OperationLocalDate.parse('2026-08-03'),
      );
      await container.food.save(
        const MealData(
          date: '2026-08-03',
          mealType: 'Water',
          items: [],
          memo: '',
          id: 'request-water',
          waterMl: 250,
        ),
      );
      final gateway = ProductionReportSyncExchangeGateway(
        container: container,
        clock: () => runtimeNow,
      );
      final response = container.reportSyncCodec.create(
        direction: ReportSyncDirection.response,
        exchangeType: ReportSyncExchangeType.food,
        exchangeId: 'response-food-1',
        operationDate: '2026-08-03',
        createdAt: runtimeNow,
        payload: {
          'operationDate': '2026-08-03',
          'meals': const [
            {
              'mealId': 'food-sync-1',
              'mealType': 'Breakfast',
              'items': [
                {
                  'name': 'Oats',
                  'calories': 100,
                  'protein': 4,
                  'fat': 2,
                  'carbohydrate': 18,
                  'quantity': 1,
                  'amount': null,
                  'baseAmount': null,
                  'baseUnit': null,
                  'amountMode': null,
                },
              ],
              'memo': '',
              'waterMl': null,
            },
          ],
        },
      );
      final raw = container.reportSyncCodec.encode(response);
      final preview = await gateway.previewResponse(
        ReportSyncExchangeType.food,
        raw,
      );
      expect(preview.disposition, ReportSyncDisposition.create);
      expect(await container.reportSyncHistory.list(), isEmpty);
      final result = await gateway.apply(preview);
      expect(result.readBackVerified, isTrue);
      expect(result.mealCounts?.received, 1);
      expect(result.mealCounts?.selected, 1);
      expect(result.mealCounts?.imported, 1);
      expect(result.mealCounts?.conflict, 0);
      expect(result.mealCounts?.excluded, 0);
      expect(await container.food.findById('food-sync-1'), isNotNull);
      final history = (await container.reportSyncHistory.list()).single;
      expect(history.receivedMealCount, 1);
      expect(history.selectedMealCount, 1);
      expect(history.importedMealCount, 1);
      expect(history.conflictMealCount, 0);
      expect(history.excludedMealCount, 0);

      final repeated = await gateway.previewResponse(
        ReportSyncExchangeType.food,
        raw,
      );
      expect(repeated.disposition, ReportSyncDisposition.noChanges);
      expect(await container.reportSyncHistory.list(), hasLength(1));
    },
  );

  test('standalone response rejects an operation date mismatch', () async {
    final container = AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase());
    await container.operationState.createInitial(
      OperationLocalDate.parse('2026-08-03'),
    );
    final response = container.reportSyncCodec.create(
      direction: ReportSyncDirection.response,
      exchangeType: ReportSyncExchangeType.food,
      exchangeId: 'response-wrong-date',
      operationDate: '2026-08-02',
      createdAt: now,
      payload: const {
        'operationDate': '2026-08-02',
        'meals': [
          {
            'mealId': 'water-wrong-date',
            'mealType': 'Water',
            'items': <Object?>[],
            'memo': null,
            'waterMl': 250,
          },
        ],
      },
    );
    expect(
      () =>
          ProductionReportSyncExchangeGateway(
            container: container,
            clock: () => now,
          ).previewResponse(
            ReportSyncExchangeType.food,
            container.reportSyncCodec.encode(response),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test(
    'food imports only selected create meals and leaves conflicts intact',
    () async {
      final database = FakeIndexedDbDatabase();
      final container = AppRepositoryContainer.indexedDb(database);
      await container.operationState.createInitial(
        OperationLocalDate.parse('2026-08-03'),
      );
      await container.food.save(
        const MealData(
          date: '2026-07-01',
          mealType: 'Water',
          items: [],
          memo: '',
          id: 'conflict',
          waterMl: 100,
        ),
      );
      final gateway = ProductionReportSyncExchangeGateway(container: container);
      final response = container.reportSyncCodec.create(
        direction: ReportSyncDirection.response,
        exchangeType: ReportSyncExchangeType.food,
        exchangeId: 'food-selection',
        operationDate: '2026-07-01',
        createdAt: DateTime.now().toUtc(),
        payload: const {
          'operationDate': '2026-07-01',
          'meals': [
            {
              'mealId': 'create-1',
              'mealType': 'Water',
              'items': <Object?>[],
              'memo': null,
              'waterMl': 200,
            },
            {
              'mealId': 'create-2',
              'mealType': 'Water',
              'items': <Object?>[],
              'memo': null,
              'waterMl': 300,
            },
            {
              'mealId': 'conflict',
              'mealType': 'Water',
              'items': <Object?>[],
              'memo': null,
              'waterMl': 999,
            },
            {
              'mealId': 'create-3',
              'mealType': 'Water',
              'items': <Object?>[],
              'memo': null,
              'waterMl': 400,
            },
          ],
        },
      );

      final preview = await gateway.previewResponse(
        ReportSyncExchangeType.food,
        container.reportSyncCodec.encode(response),
        targetDate: '2026-07-01',
      );
      expect(preview.createCount, 3);
      expect(preview.conflictCount, 1);
      expect(preview.foodMeals.where((meal) => meal.canSelect), hasLength(3));
      final transactionCountBeforeApply = database.transactionCount;
      final result = await gateway.apply(
        preview,
        selectedMealIds: const {'create-1', 'create-2'},
      );
      expect(database.transactionCount, transactionCountBeforeApply + 1);
      expect(result.readBackVerified, isTrue);
      expect(await container.food.findById('create-1'), isNotNull);
      expect((await container.food.findById('create-2'))?.waterMl, 300);
      expect(await container.food.findById('create-3'), isNull);
      expect((await container.food.findById('conflict'))?.waterMl, 100);
      expect(result.mealCounts?.received, 4);
      expect(result.mealCounts?.selected, 2);
      expect(result.mealCounts?.imported, 2);
      expect(result.mealCounts?.conflict, 1);
      expect(result.mealCounts?.excluded, 2);
      final history = (await container.reportSyncHistory.list()).single;
      expect(history.recordVersion, 3);
      expect(history.receivedMealCount, 4);
      expect(history.selectedMealCount, 2);
      expect(history.importedMealCount, 2);
      expect(history.conflictMealCount, 1);
      expect(history.excludedMealCount, 2);
      expect(history.importedMealSnapshots.map((meal) => meal.id), [
        'create-1',
        'create-2',
      ]);
      await container.food.deleteById('create-1');
      final retainedHistory = (await container.reportSyncHistory.list()).single;
      expect(retainedHistory.importedMealSnapshots.map((meal) => meal.id), [
        'create-1',
        'create-2',
      ]);
    },
  );

  test('food transaction rollback creates no success History', () async {
    final database = FakeIndexedDbDatabase();
    final container = AppRepositoryContainer.indexedDb(database);
    await container.operationState.createInitial(
      OperationLocalDate.parse('2026-08-03'),
    );
    final gateway = ProductionReportSyncExchangeGateway(container: container);
    final response = container.reportSyncCodec.create(
      direction: ReportSyncDirection.response,
      exchangeType: ReportSyncExchangeType.food,
      exchangeId: 'food-rollback',
      operationDate: '2026-08-03',
      createdAt: DateTime.now().toUtc(),
      payload: const {
        'operationDate': '2026-08-03',
        'meals': [
          {
            'mealId': 'rollback-meal',
            'mealType': 'Water',
            'items': <Object?>[],
            'memo': null,
            'waterMl': 200,
          },
        ],
      },
    );
    final preview = await gateway.previewResponse(
      ReportSyncExchangeType.food,
      container.reportSyncCodec.encode(response),
    );
    database.failNextTransactionWith = StateError('rollback');

    await expectLater(
      gateway.apply(preview),
      throwsA(
        isA<ReportSyncApplyException>().having(
          (error) => error.code,
          'code',
          'food_transaction_failed',
        ),
      ),
    );
    expect(await container.food.findById('rollback-meal'), isNull);
    expect(await container.reportSyncHistory.list(), isEmpty);
  });

  test('food import rolls back every MEAL when History put fails', () async {
    final database = FakeIndexedDbDatabase();
    final fixture = await _foodImportFixture(
      database,
      exchangeId: 'food-history-put-failure',
      mealIds: const ['history-meal-1', 'history-meal-2'],
    );
    database.failNextPutForStore = IndexedDbStoreNames.reportSyncHistory;

    await expectLater(
      fixture.gateway.apply(fixture.preview),
      throwsA(
        isA<ReportSyncApplyException>().having(
          (error) => error.code,
          'code',
          'history_record_put_failed',
        ),
      ),
    );
    expect(await fixture.container.food.findById('history-meal-1'), isNull);
    expect(await fixture.container.food.findById('history-meal-2'), isNull);
    expect(await fixture.container.reportSyncHistory.list(), isEmpty);
  });

  test(
    'food import rolls back MEAL and History on read-back failure',
    () async {
      final database = FakeIndexedDbDatabase();
      final fixture = await _foodImportFixture(
        database,
        exchangeId: 'food-read-back-failure',
        mealIds: const ['read-back-meal'],
      );
      database.failNextReadAfterPutForStore = IndexedDbStoreNames.foodRecords;

      await expectLater(
        fixture.gateway.apply(fixture.preview),
        throwsA(
          isA<ReportSyncApplyException>().having(
            (error) => error.code,
            'code',
            'food_read_back_failed',
          ),
        ),
      );
      expect(await fixture.container.food.findById('read-back-meal'), isNull);
      expect(await fixture.container.reportSyncHistory.list(), isEmpty);
    },
  );

  test(
    'Training Report Sync previews and imports a null-name historical record',
    () async {
      final container = AppRepositoryContainer.indexedDb(
        FakeIndexedDbDatabase(),
      );
      await container.operationState.createInitial(
        OperationLocalDate.parse('2026-08-01'),
      );
      final gateway = ProductionReportSyncExchangeGateway(
        container: container,
        trainingIdGenerator: TrainingRecordIdGenerator(nextInt: (_) => 0),
      );
      final response = _historicalTrainingEnvelope(
        _trainingV2Payload(sessionName: null),
      );

      final preview = await gateway.previewResponse(
        ReportSyncExchangeType.training,
        jsonEncode(response),
        targetDate: '2026-08-01',
      );
      expect(preview.disposition, ReportSyncDisposition.create);
      expect(preview.trainingPreview?.invalidCount, 0);
      expect(preview.trainingPreview?.blockedCount, 0);
      expect(
        preview
            .trainingPreview
            ?.records
            .single
            .persistedRecord!
            .dataV2
            .sessionName,
        isNull,
      );
      final result = await gateway.apply(preview);
      expect(result.readBackVerified, isTrue);
      const generatedId = 'training:00000000-0000-4000-8000-000000000000';
      final stored = await container.training.findRecordById(generatedId);
      expect(stored?.id, generatedId);
      expect(stored?.id, isNot('TR-2026-08-01'));
      expect(stored?.v2Data?.sessionName, isNull);
      expect(stored?.v2Data?.exercises.single.nextTarget?.notes, '次も継続');
    },
  );

  test(
    'Food Schema 2 uses content conflict and transient selection identity',
    () async {
      final container = AppRepositoryContainer.indexedDb(
        FakeIndexedDbDatabase(),
      );
      await container.operationState.createInitial(
        OperationLocalDate.parse('2026-08-01'),
      );
      await container.food.save(
        MealData(
          date: '2026-08-01',
          mealType: 'Breakfast',
          items: const [
            FoodItem(
              name: 'Oats',
              calories: 100,
              protein: 4,
              fat: 2,
              carbohydrate: 18,
            ),
          ],
          memo: '',
          id: 'legacy-existing',
        ),
      );
      final gateway = ProductionReportSyncExchangeGateway(container: container);
      final response = container.reportSyncCodec.create(
        direction: ReportSyncDirection.response,
        exchangeType: ReportSyncExchangeType.food,
        exchangeId: 'food-schema-2',
        operationDate: '2026-08-01',
        createdAt: DateTime.now().toUtc(),
        schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
        payload: {
          'operationDate': '2026-08-01',
          'meals': [
            _foodV2Meal('chatgpt-breakfast', 'Breakfast', 'Oats', 100),
            _foodV2Meal(null, 'Breakfast', 'Eggs', 80),
            _foodV2Meal('chatgpt-lunch', 'Lunch', 'Rice', 200),
          ],
        },
      );

      final preview = await gateway.previewResponse(
        ReportSyncExchangeType.food,
        container.reportSyncCodec.encode(response),
        targetDate: '2026-08-01',
      );
      expect(preview.foodMeals, hasLength(3));
      expect(preview.conflictCount, 1);
      expect(preview.createCount, 2);
      expect(preview.foodMeals.first.canSelect, isFalse);
      expect(preview.foodMeals[1].previewId, 'food-preview-1');
      expect(preview.foodMeals[2].previewId, 'food-preview-2');
      final result = await gateway.apply(
        preview,
        selectedMealIds: {preview.foodMeals[2].previewId},
      );
      expect(result.readBackVerified, isTrue);
      expect(result.mealCounts?.selected, 1);
      expect(result.mealCounts?.conflict, 1);
      final stored = await container.food.findByLocalDate('2026-08-01');
      expect(stored, hasLength(2));
      final imported = stored.singleWhere((meal) => meal.mealType == 'Lunch');
      expect(imported.id, matches(RegExp(r'^food:[0-9a-f-]{36}$')));
      expect(imported.id, isNot('chatgpt-lunch'));
    },
  );

  test('Food Schema 2 regenerates a colliding formal Meal ID', () async {
    final container = AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase());
    await container.operationState.createInitial(
      OperationLocalDate.parse('2026-08-01'),
    );
    await container.food.save(
      const MealData(
        date: '2026-08-01',
        mealType: 'Snack',
        items: [],
        memo: '',
        id: 'food:00000000-0000-4000-8000-000000000000',
        waterMl: 100,
      ),
    );
    var calls = 0;
    final gateway = ProductionReportSyncExchangeGateway(
      container: container,
      foodIdGenerator: FoodMealIdGenerator(
        nextInt: (_) => calls++ < 16 ? 0 : 1,
      ),
    );
    final response = container.reportSyncCodec.create(
      direction: ReportSyncDirection.response,
      exchangeType: ReportSyncExchangeType.food,
      exchangeId: 'food-id-collision',
      operationDate: '2026-08-01',
      createdAt: DateTime.now().toUtc(),
      schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
      payload: {
        'operationDate': '2026-08-01',
        'meals': [_foodV2Meal(null, 'Lunch', 'Rice', 200)],
      },
    );

    final preview = await gateway.previewResponse(
      ReportSyncExchangeType.food,
      container.reportSyncCodec.encode(response),
      targetDate: '2026-08-01',
    );
    expect(
      preview.foodMeals.single.meal.id,
      isNot('food:00000000-0000-4000-8000-000000000000'),
    );
    expect(
      preview.foodMeals.single.meal.id,
      'food:01010101-0101-4101-8101-010101010101',
    );
  });
}

Future<
  ({
    AppRepositoryContainer container,
    ProductionReportSyncExchangeGateway gateway,
    ReportSyncResponsePreview preview,
  })
>
_foodImportFixture(
  FakeIndexedDbDatabase database, {
  required String exchangeId,
  required List<String> mealIds,
}) async {
  final container = AppRepositoryContainer.indexedDb(database);
  await container.operationState.createInitial(
    OperationLocalDate.parse('2026-08-03'),
  );
  final gateway = ProductionReportSyncExchangeGateway(container: container);
  final response = container.reportSyncCodec.create(
    direction: ReportSyncDirection.response,
    exchangeType: ReportSyncExchangeType.food,
    exchangeId: exchangeId,
    operationDate: '2026-08-03',
    createdAt: DateTime.utc(2026, 8, 3),
    payload: {
      'operationDate': '2026-08-03',
      'meals': [
        for (final id in mealIds)
          {
            'mealId': id,
            'mealType': 'Water',
            'items': <Object?>[],
            'memo': null,
            'waterMl': 200,
          },
      ],
    },
  );
  final preview = await gateway.previewResponse(
    ReportSyncExchangeType.food,
    container.reportSyncCodec.encode(response),
  );
  return (container: container, gateway: gateway, preview: preview);
}

Map<String, Object?> _historicalTrainingEnvelope(Map<String, Object?> record) =>
    {
      'format': 'operation-reboot-operation-sync',
      'envelopeVersion': 1,
      'schemaVersion': '1.0',
      'direction': 'response',
      'exchangeType': 'historicalTraining',
      'exchangeId': 'training-report-sync-response',
      'createdAt': '2026-08-01T00:00:00.000Z',
      'payload': {
        'recordType': 'trainingV2',
        'sourceMode': 'dateRange',
        'importMode': 'missingRecordsOnly',
        'requestedStartDate': '2026-08-01',
        'requestedEndDate': '2026-08-01',
        'records': [record],
      },
      'packageDigest': null,
    };

Map<String, Object?> _trainingV2Payload({Object? sessionName = 'Session'}) => {
  'operationDate': '2026-08-01',
  'sourceRecordId': 'TR-2026-08-01',
  'session': {
    'session': {
      'localDate': '2026-08-01',
      'name': sessionName,
      'grade': 'a',
      'memo': null,
      'dynamicStretchCompleted': false,
      'cooldownStretchCompleted': false,
      'overallEvaluation': null,
    },
    'exercises': [
      {
        'exerciseName': 'Bench Press',
        'equipment': {'id': null, 'name': 'Power Rack'},
        'sets': [
          {
            'type': 'main',
            'weightKg': 60,
            'reps': 5,
            'rpe': null,
            'restAfterSeconds': 90,
          },
        ],
        'evaluation': null,
        'nextTarget': '次も継続',
      },
    ],
    'cardio': <Object?>[],
  },
};

Map<String, Object?> _foodV2Meal(
  String? sourceMealId,
  String mealType,
  String name,
  num calories,
) => {
  'sourceMealId': sourceMealId,
  'mealType': mealType,
  'items': [
    {
      'name': name,
      'calories': calories,
      'protein': name == 'Oats' ? 4 : 0,
      'fat': name == 'Oats' ? 2 : 0,
      'carbohydrate': name == 'Oats' ? 18 : 0,
      'quantity': 1,
      'amount': null,
      'baseAmount': null,
      'baseUnit': null,
      'amountMode': null,
    },
  ],
  'memo': null,
  'waterMl': null,
};

Map<String, Object?> _morningBriefPayload(
  StatusReportSyncSourceExport source,
) => {
  'operationDate': source.source.operationDate,
  'source': {
    'sourceType': 'status',
    'sourceOperationDate': source.source.operationDate,
    'sourceRecordId': source.source.sourceRecordId,
    'sourceDigest': source.sourceDigest,
  },
  'content': {
    'situationAnalysis': {
      'body': '体重と体脂肪率は正式記録どおりです。',
      'recovery': '睡眠時間と睡眠スコアを確認しました。',
      'condition': '足の痛みを考慮します。',
      'work': '勤務時間を考慮します。',
      'carryover': '前日情報は利用できません。',
      'overall': '負荷を抑えて安定運用します。',
    },
    'operatingPolicy': '回復を優先しながら必要事項を進めます。',
    'strategicResourceDecision': {
      'decision': '回復資源を優先します。',
      'targetResource': null,
      'rationale': '足の痛みが記録されているためです。',
      'execution': null,
    },
    'operationStatus': 'green',
    'commanderIntent': '回復を守りながら重要事項を確実に進めます。',
    'actions': const [
      {'text': '足の状態を確認してから行動します。', 'priority': 'high'},
    ],
  },
};

MorningData _status(String date) => MorningData(
  date: date,
  weight: 70,
  bodyFat: 20,
  sleepHours: 7,
  sleepScore: 80,
  footPain: 3,
  workType: WorkType.work,
  workStart: '09:00',
  workEnd: '18:00',
  workBreak: '01:00',
  workHours: 8,
  memo: '',
);
