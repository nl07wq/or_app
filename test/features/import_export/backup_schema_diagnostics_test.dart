import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_schema_diagnostics.dart';
import 'package:or_app/features/import_export/services/backup_store_registry.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/operation_date/services/daily_finalize_backup_verifier.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test('record schema mismatch produces field-shape diagnostics only', () {
    const privateId = 'patient-record-id-should-not-leak';
    const privateValue = 'private-health-value-should-not-leak';
    final malformed = <String, Object?>{
      'id': privateId,
      'recordVersion': 'one',
      'localDate': 123,
      'createdAt': privateValue,
      'updatedAt': privateValue,
      'recordKind': 'canonical',
      'unexpectedField': privateValue,
    };

    BackupSchemaDiagnostics? diagnostics;
    try {
      BackupStoreRegistry.validateAndSort(BackupSections.status, [malformed]);
      fail('Expected the malformed STATUS record to fail validation.');
    } on BackupRecordValidationException catch (error) {
      diagnostics = error.diagnostics;
    }

    final result = diagnostics;
    expect(result.validationStage, 'record_schema_validation');
    expect(result.validationSubstage, 'record_parser');
    expect(result.failureCategory, 'format_exception');
    expect(result.store, isNotEmpty);
    expect(result.recordType, BackupSections.status);
    expect(result.backupSchemaVersion, BackupPackage.currentSchemaVersion);
    expect(result.missingFields, contains('data'));
    expect(result.unexpectedFields, contains('unexpectedField'));
    expect(
      result.actualFields.map((item) => item.toCopyText()),
      contains('recordVersion:String'),
    );
    expect(
      result.typeMismatches.map((item) => item.toCopyText()).join(';'),
      contains('recordVersion:int->String'),
    );
    expect(
      result.typeMismatches.map((item) => item.toCopyText()).join(';'),
      contains('localDate:String->int'),
    );

    final copied = result.toCopyText();
    expect(copied, isNot(contains(privateId)));
    expect(copied, isNot(contains(privateValue)));
    expect(copied, isNot(contains('123')));
  });

  test('unavailable diagnostics identify the last validation boundary', () {
    final diagnostics = backupSchemaDiagnosticsForFailure(
      const BackupException('invalid_record', 'sensitive value is excluded'),
      fallbackStage: 'backup_package_validation',
    );

    expect(diagnostics.detailedFieldComparisonAvailable, isFalse);
    expect(diagnostics.store, isNull);
    expect(diagnostics.validationSubstage, 'no_structured_diagnostic');
    expect(diagnostics.failureCategory, 'backup_contract');
    expect(
      diagnostics.unavailableReason,
      'failure_did_not_provide_record_context',
    );
    expect(diagnostics.toCopyText(), contains('store=unavailable'));
    expect(diagnostics.toCopyText(), contains('expectedFields=unavailable'));
    expect(
      diagnostics.toCopyText(),
      contains('validationStage=backup_package_validation'),
    );
  });

  test('structured diagnostics survive the FINALIZE verifier boundary', () {
    final generated = BackupSchemaDiagnostics.forRecord(
      section: BackupSections.status,
      store: 'statusRecords',
      record: const {
        'id': 'private-id',
        'recordVersion': 1,
        'localDate': '2026-11-01',
        'createdAt': '2026-11-01T00:00:00.000Z',
        'updatedAt': '2026-11-01T00:00:00.000Z',
        'recordKind': 'canonical',
        'data': <String, Object?>{},
      },
      validationStage: 'backup_snapshot_validation',
      validationSubstage: 'operation_state_integrity',
      failureCategory: 'backup_contract',
    );

    final retained = backupSchemaDiagnosticsForFailure(
      BackupValidationDiagnosticsException(generated),
      fallbackStage: 'backup_snapshot_validation',
    );

    expect(identical(retained, generated), isTrue);
    expect(retained.validationSubstage, 'operation_state_integrity');
    expect(retained.toCopyText(), isNot(contains('private-id')));
  });

  test(
    'snapshot record validation retains its store context for FINALIZE',
    () async {
      final database = FakeIndexedDbDatabase();
      final controller = AppInitializationController()..markReady();
      final timestamp = DateTime.utc(2026, 11, 1);
      database.seed(
        IndexedDbStoreNames.operationState,
        OperationState.canonicalId,
        OperationState(
          operationDate: OperationLocalDate.parse('2026-11-01'),
          createdAt: timestamp,
          updatedAt: timestamp,
        ).toRecord(),
      );
      database.seed(IndexedDbStoreNames.statusRecords, 'private-id', {
        'id': 'private-id',
        'recordVersion': 'invalid',
      });

      await expectLater(
        BackupExportService(
          database: database,
          controller: controller,
        ).create(),
        throwsA(
          isA<BackupValidationDiagnosticsException>()
              .having(
                (error) => error.diagnostics.store,
                'store',
                IndexedDbStoreNames.statusRecords,
              )
              .having(
                (error) => error.diagnostics.recordType,
                'record type',
                BackupSections.status,
              )
              .having(
                (error) => error.diagnostics.validationSubstage,
                'substage',
                'record_parser',
              ),
        ),
      );
    },
  );

  test(
    'operation integrity failures retain the final snapshot substage',
    () async {
      final database = FakeIndexedDbDatabase();
      final controller = AppInitializationController()..markReady();
      final timestamp = DateTime.utc(2026, 11, 2);
      database.seed(
        IndexedDbStoreNames.operationState,
        OperationState.canonicalId,
        OperationState(
          operationDate: OperationLocalDate.parse('2026-11-02'),
          lastFinalizedDate: OperationLocalDate.parse('2026-11-01'),
          createdAt: timestamp,
          updatedAt: timestamp,
        ).toRecord(),
      );

      await expectLater(
        BackupExportService(
          database: database,
          controller: controller,
        ).create(),
        throwsA(
          isA<BackupValidationDiagnosticsException>()
              .having(
                (error) => error.diagnostics.validationSubstage,
                'substage',
                'operation_state_integrity',
              )
              .having(
                (error) => error.diagnostics.store,
                'store',
                IndexedDbStoreNames.operationState,
              )
              .having(
                (error) => error.diagnostics.recordType,
                'record type',
                BackupSections.operationState,
              ),
        ),
      );
    },
  );
}
