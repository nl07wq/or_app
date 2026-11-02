import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/services/backup_schema_diagnostics.dart';
import 'package:or_app/features/import_export/services/backup_store_registry.dart';

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

  test('unavailable diagnostics report only their failure stage', () {
    final diagnostics = BackupSchemaDiagnostics.unavailable(
      validationStage: 'backup_package_validation',
    );

    expect(diagnostics.detailedFieldComparisonAvailable, isFalse);
    expect(diagnostics.store, isNull);
    expect(diagnostics.toCopyText(), contains('store=unavailable'));
    expect(diagnostics.toCopyText(), contains('expectedFields=unavailable'));
    expect(
      diagnostics.toCopyText(),
      contains('validationStage=backup_package_validation'),
    );
  });
}
