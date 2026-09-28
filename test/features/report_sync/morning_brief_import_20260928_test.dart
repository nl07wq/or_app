import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/report_sync/models/report_sync_envelope.dart';
import 'package:or_app/features/report_sync/services/report_sync_exchange_gateway.dart';
import 'package:or_app/features/report_sync/services/report_sync_persistence_service.dart';
import 'package:or_app/features/report_sync/services/status_report_sync_source_service.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  const operationDate = '2026-09-28';

  test(
    'imports the supplied future-dated Morning Brief without mutation loss',
    () async {
      final database = FakeIndexedDbDatabase();
      final container = AppRepositoryContainer.indexedDb(database);
      await container.operationState.createInitial(
        OperationLocalDate.parse(operationDate),
      );
      await container.status.save(_status('2026-09-27', weight: 93.4));
      await container.status.save(_status(operationDate, weight: 92.8));

      final raw = (await File(
        'test/fixtures/report_sync/morning_brief_20260928_unexpected_import_failure.json',
      ).readAsString()).trim();
      final response = container.reportSyncCodec.decode(raw);
      expect(response.schemaVersion, ReportSyncEnvelope.importSchemaVersion2);
      expect(response.confirmationDigest, isNull);
      expect(response.packageDigest, isNotEmpty);

      // The payload fixture remains byte-for-byte unchanged. The test binds
      // only its source identity to the local fake STATUS record because the
      // production source record is external to the repository fixture.
      final source = await StatusReportSyncSourceService(database).generate(
        operationDate: operationDate,
        exportedAt: DateTime.utc(2026, 9, 28, 9, 24),
      );
      final boundPayload = Map<String, Object?>.from(response.payload);
      boundPayload['source'] = {
        'sourceType': 'status',
        'sourceOperationDate': operationDate,
        'sourceRecordId': source.source.sourceRecordId,
        'sourceDigest': source.sourceDigest,
      };
      final boundResponse = container.reportSyncCodec.create(
        direction: response.direction,
        schemaVersion: response.schemaVersion,
        exchangeType: response.exchangeType,
        exchangeId: response.exchangeId,
        operationDate: response.operationDate,
        createdAt: response.createdAt,
        confirmationDigest: response.confirmationDigest,
        payload: boundPayload,
      );

      final gateway = ProductionReportSyncExchangeGateway(
        container: container,
        clock: () => DateTime.utc(2026, 9, 28, 9, 24),
      );
      final preview = await gateway.previewResponse(
        ReportSyncExchangeType.morningBrief,
        container.reportSyncCodec.encode(boundResponse),
        targetDate: operationDate,
      );
      expect(preview.canApply, isTrue);

      final transactionsBeforeImport = database.transactionCount;
      database.failNextPutForStore = IndexedDbStoreNames.morningBriefRecords;
      await expectLater(
        gateway.apply(preview),
        throwsA(isA<ReportSyncImportFailure>()),
      );
      expect(
        await container.morningBriefs.readByLocalDate(operationDate),
        isNull,
      );
      expect(
        await container.reportSyncHistory.readById(response.exchangeId),
        isNull,
      );

      final successPreview = await gateway.previewResponse(
        ReportSyncExchangeType.morningBrief,
        container.reportSyncCodec.encode(boundResponse),
        targetDate: operationDate,
      );
      final result = await gateway.apply(successPreview);
      expect(result.readBackVerified, isTrue);
      expect(database.transactionCount, transactionsBeforeImport + 2);

      final saved = await container.morningBriefs.readByLocalDate(
        operationDate,
      );
      expect(saved?.operationStatus.stableId, 'green');
      expect(saved?.commanderIntent, contains('公休日を低負荷で安定運用'));
      expect(saved?.actions, hasLength(3));
      expect(saved?.actions.map((action) => action.priority), [
        'medium',
        'low',
        'low',
      ]);
      expect(saved?.decisionTrace?.finalDecision.operationStatus, 'green');
      expect(
        await container.reportSyncHistory.readById(response.exchangeId),
        isNotNull,
      );
    },
  );
}

MorningData _status(String date, {required double weight}) => MorningData(
  date: date,
  weight: weight,
  bodyFat: 31.5,
  sleepHours: 6.5,
  sleepScore: 83,
  footPain: 3,
  workType: WorkType.holiday,
  workStart: '',
  workEnd: '',
  workBreak: '',
  workHours: 0,
  memo: '',
);
