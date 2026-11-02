import '../models/backup_package.dart';

/// A safe, field-shape-only description of a backup record validation failure.
///
/// This deliberately excludes record identifiers, field values, timestamps, and
/// the original exception message. It is intended for user-initiated copy from
/// a FINALIZE failure presentation, not telemetry or automatic reporting.
class BackupSchemaDiagnostics {
  final String validationStage;
  final String validationSubstage;
  final String failureCategory;
  final String? unavailableReason;
  final String? store;
  final String? recordType;
  final int backupSchemaVersion;
  final String recordSchemaVersion;
  final List<String> expectedFields;
  final List<BackupSchemaField> actualFields;
  final List<String> missingFields;
  final List<String> unexpectedFields;
  final List<BackupSchemaTypeMismatch> typeMismatches;
  final bool detailedFieldComparisonAvailable;

  const BackupSchemaDiagnostics({
    required this.validationStage,
    required this.validationSubstage,
    required this.failureCategory,
    required this.unavailableReason,
    required this.store,
    required this.recordType,
    required this.backupSchemaVersion,
    required this.recordSchemaVersion,
    required this.expectedFields,
    required this.actualFields,
    required this.missingFields,
    required this.unexpectedFields,
    required this.typeMismatches,
    required this.detailedFieldComparisonAvailable,
  });

  factory BackupSchemaDiagnostics.forRecord({
    required String section,
    required String? store,
    required Map<String, Object?> record,
    required String validationStage,
    required String validationSubstage,
    required String failureCategory,
  }) {
    final specification = _specifications[section];
    final actualFields = record.keys.where(_isSafeFieldName).toSet();
    final expectedTypes = specification?.expectedTypes ?? const {};
    final allowedFields = specification?.allowedFields ?? const <String>{};
    final missing = specification == null
        ? <String>[]
        : specification.requiredFields.difference(actualFields).toList();
    missing.sort();
    final unexpected = specification == null
        ? <String>[]
        : actualFields.difference(allowedFields).toList();
    unexpected.sort();
    final expectedFields = specification == null
        ? <String>[]
        : specification.allowedFields.toList();
    expectedFields.sort();
    final mismatches = <BackupSchemaTypeMismatch>[];
    for (final entry in expectedTypes.entries) {
      final value = record[entry.key];
      if (value == null && specification!.nullableFields.contains(entry.key)) {
        continue;
      }
      final actualType = _valueType(value);
      if (actualType != entry.value) {
        mismatches.add(
          BackupSchemaTypeMismatch(
            field: entry.key,
            expectedType: entry.value,
            actualType: actualType,
          ),
        );
      }
    }
    final recordVersion = record['recordVersion'];
    return BackupSchemaDiagnostics(
      validationStage: validationStage,
      validationSubstage: validationSubstage,
      failureCategory: failureCategory,
      unavailableReason: specification == null
          ? 'record_field_contract_not_registered'
          : null,
      store: store,
      recordType: section,
      backupSchemaVersion: BackupPackage.currentSchemaVersion,
      recordSchemaVersion: recordVersion is int
          ? recordVersion.toString()
          : 'unavailable (${_valueType(recordVersion)})',
      expectedFields: List.unmodifiable(expectedFields),
      actualFields: List.unmodifiable(
        actualFields
            .map(
              (field) => BackupSchemaField(
                name: field,
                type: _valueType(record[field]),
              ),
            )
            .toList()
          ..sort((first, second) => first.name.compareTo(second.name)),
      ),
      missingFields: List.unmodifiable(missing),
      unexpectedFields: List.unmodifiable(unexpected),
      typeMismatches: List.unmodifiable(mismatches),
      detailedFieldComparisonAvailable: specification != null,
    );
  }

  factory BackupSchemaDiagnostics.unavailable({
    required String validationStage,
    required String validationSubstage,
    required String failureCategory,
    required String unavailableReason,
    String? store,
    String? recordType,
  }) => BackupSchemaDiagnostics(
    validationStage: validationStage,
    validationSubstage: validationSubstage,
    failureCategory: failureCategory,
    unavailableReason: unavailableReason,
    store: store,
    recordType: recordType,
    backupSchemaVersion: BackupPackage.currentSchemaVersion,
    recordSchemaVersion: 'unavailable',
    expectedFields: const [],
    actualFields: const [],
    missingFields: const [],
    unexpectedFields: const [],
    typeMismatches: const [],
    detailedFieldComparisonAvailable: false,
  );

  /// Stable, copy-safe text: no exception messages, IDs, or field values.
  String toCopyText() {
    final lines = <String>[
      'FINALIZE_SCHEMA_DIAGNOSTICS_V1',
      'validationStage=$validationStage',
      'validationSubstage=$validationSubstage',
      'failureCategory=$failureCategory',
      'unavailableReason=${unavailableReason ?? 'none'}',
      'backupSchemaVersion=$backupSchemaVersion',
      'store=${store ?? 'unavailable'}',
      'recordType=${recordType ?? 'unavailable'}',
      'recordSchemaVersion=$recordSchemaVersion',
      'detailedFieldComparisonAvailable=$detailedFieldComparisonAvailable',
      'expectedFields=${expectedFields.isEmpty && !detailedFieldComparisonAvailable ? 'unavailable' : expectedFields.join(',')}',
      'actualFields=${actualFields.map((item) => item.toCopyText()).join(',')}',
      'missingFields=${missingFields.join(',')}',
      'unexpectedFields=${unexpectedFields.join(',')}',
      'typeMismatches=${typeMismatches.map((item) => item.toCopyText()).join(';')}',
    ];
    return lines.join('\n');
  }

  static bool _isSafeFieldName(String value) =>
      RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,63}$').hasMatch(value);

  static String _valueType(Object? value) => switch (value) {
    null => 'null',
    String _ => 'String',
    bool _ => 'bool',
    int _ => 'int',
    double _ => 'double',
    Map _ => 'object',
    Iterable _ => 'array',
    _ => 'unsupported',
  };
}

class BackupSchemaField {
  final String name;
  final String type;

  const BackupSchemaField({required this.name, required this.type});

  String toCopyText() => '$name:$type';
}

class BackupSchemaTypeMismatch {
  final String field;
  final String expectedType;
  final String actualType;

  const BackupSchemaTypeMismatch({
    required this.field,
    required this.expectedType,
    required this.actualType,
  });

  String toCopyText() => '$field:$expectedType->$actualType';
}

class BackupValidationDiagnosticsException extends BackupException {
  final BackupSchemaDiagnostics diagnostics;

  const BackupValidationDiagnosticsException(this.diagnostics)
    : super('backup_validation_diagnostic', 'Backup validation failed.');

  @override
  String toString() =>
      'backup_schema_validation_failed at ${diagnostics.validationStage}';
}

class BackupRecordValidationException
    extends BackupValidationDiagnosticsException {
  const BackupRecordValidationException(super.diagnostics);
}

class _RecordSpecification {
  final Set<String> requiredFields;
  final Set<String> nullableFields;
  final Map<String, String> expectedTypes;

  const _RecordSpecification({
    required this.requiredFields,
    this.nullableFields = const {},
    required this.expectedTypes,
  });

  Set<String> get allowedFields => {...expectedTypes.keys, ...nullableFields};
}

const _specifications = <String, _RecordSpecification>{
  BackupSections.status: _RecordSpecification(
    requiredFields: {
      'id',
      'recordVersion',
      'localDate',
      'createdAt',
      'updatedAt',
      'recordKind',
      'data',
    },
    nullableFields: {'canonicalDate', 'migrationSource'},
    expectedTypes: {
      'id': 'String',
      'recordVersion': 'int',
      'localDate': 'String',
      'createdAt': 'String',
      'updatedAt': 'String',
      'canonicalDate': 'String',
      'recordKind': 'String',
      'migrationSource': 'object',
      'data': 'object',
    },
  ),
  BackupSections.morningBriefRecords: _RecordSpecification(
    requiredFields: {
      'localDate',
      'recordVersion',
      'sourceType',
      'sourceOperationDate',
      'sourceRecordId',
      'sourceDigest',
      'responseDigest',
      'exchangeId',
      'generatedAt',
      'importedAt',
      'situationAnalysis',
      'operatingPolicy',
      'strategicResourceDecision',
      'operationStatus',
      'commanderIntent',
      'actions',
      'createdAt',
      'updatedAt',
      'revision',
      'previousRevisions',
    },
    nullableFields: {'evaluationVersion', 'decisionTrace'},
    expectedTypes: {
      'localDate': 'String',
      'recordVersion': 'int',
      'sourceType': 'String',
      'sourceOperationDate': 'String',
      'sourceRecordId': 'String',
      'sourceDigest': 'String',
      'evaluationVersion': 'String',
      'decisionTrace': 'object',
      'responseDigest': 'String',
      'exchangeId': 'String',
      'generatedAt': 'String',
      'importedAt': 'String',
      'situationAnalysis': 'object',
      'operatingPolicy': 'String',
      'strategicResourceDecision': 'object',
      'operationStatus': 'String',
      'commanderIntent': 'String',
      'actions': 'array',
      'createdAt': 'String',
      'updatedAt': 'String',
      'revision': 'int',
      'previousRevisions': 'array',
      'archivedRevisions': 'array',
    },
  ),
};
