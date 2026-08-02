import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/daily_log_confirmation.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/report_sync/models/report_sync_envelope.dart';
import 'package:or_app/features/report_sync/services/report_sync_exchange_gateway.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  final now = DateTime.utc(2026, 8, 3, 9);

  test(
    'production gateway prepares all four exchanges from formal facts',
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
          updatedAt: now,
        ),
        expectedRevision: initial.revision,
      );
      await container.status.save(_status('2026-08-03'));
      await container.training.saveNewV2(TrainingSessionV2(date: '2026-08-03'));
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
        expect(prepared.isReady, isTrue, reason: type.stableId);
        expect(prepared.envelope!.exchangeType, type);
        expect(
          prepared.envelope!.operationDate,
          type == ReportSyncExchangeType.dailyDebrief
              ? '2026-08-02'
              : '2026-08-03',
        );
        expect(prepared.envelope!.hasValidPackageDigest, isTrue);
      }

      final morning = (await gateway.prepareRequest(
        ReportSyncExchangeType.morningBrief,
      )).envelope!;
      expect(morning.payload.toString(), isNot(contains('bowel')));
      final training = (await gateway.prepareRequest(
        ReportSyncExchangeType.training,
      )).envelope!;
      expect(training.payload['currentSession'], isNotNull);
      final debrief = (await gateway.prepareRequest(
        ReportSyncExchangeType.dailyDebrief,
      )).envelope!;
      expect(debrief.payload['confirmationDigest'], isNotNull);
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
      final gateway = ProductionReportSyncExchangeGateway(
        container: container,
        clock: () => runtimeNow,
      );
      final request = (await gateway.prepareRequest(
        ReportSyncExchangeType.food,
      )).envelope!;
      await gateway.recordRequest(request);
      final response = container.reportSyncCodec.create(
        direction: ReportSyncDirection.response,
        exchangeType: ReportSyncExchangeType.food,
        exchangeId: 'response-food-1',
        requestId: request.requestId,
        operationDate: request.operationDate,
        createdAt: runtimeNow,
        requestDigest: request.requestDigest,
        payload: {
          'requestId': request.requestId,
          'requestDigest': request.requestDigest,
          'operationDate': request.operationDate,
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
      expect((await gateway.apply(preview)).readBackVerified, isTrue);
      expect(await container.food.findById('food-sync-1'), isNotNull);

      final repeated = await gateway.previewResponse(
        ReportSyncExchangeType.food,
        raw,
      );
      expect(repeated.disposition, ReportSyncDisposition.noChanges);
    },
  );
}

MorningData _status(String date) => MorningData(
  date: date,
  weight: 70,
  bodyFat: 20,
  sleepHours: 7,
  sleepScore: 80,
  footPain: 0,
  workType: WorkType.work,
  workStart: '09:00',
  workEnd: '18:00',
  workBreak: '01:00',
  workHours: 8,
  memo: '',
);
