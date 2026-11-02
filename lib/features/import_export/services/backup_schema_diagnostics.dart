import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../models/backup_package.dart';

/// A safe, field-shape-only description of a backup record validation failure.
///
/// This deliberately excludes record identifiers, field values, timestamps, and
/// the original exception message. It is intended for user-initiated copy from
/// a FINALIZE failure presentation, not telemetry or automatic reporting.
class BackupSchemaDiagnostics {
  final String validationStage;
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
    required Map<String, Object?> record,
    required String validationStage,
  }) {
    final specification = _specifications[section];
    final actualFields = record.keys.where(_isSafeFieldName).toSet();
    final expectedTypes = specification?.expectedTypes ?? const {};
    final allowedFields = specification?.allowedFields ?? const <String>{};
    final missing =
        specification == null
              ? const <String>[]
              : specification.requiredFields.difference(actualFields).toList()
          ..sort();
    final unexpected =
        specification == null
              ? const <String>[]
              : actualFields.difference(allowedFields).toList()
          ..sort();
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
      store: BackupStoreRegistryNames.storeFor(section),
      recordType: section,
      backupSchemaVersion: BackupPackage.currentSchemaVersion,
      recordSchemaVersion: recordVersion is int
          ? recordVersion.toString()
          : 'unavailable (${_valueType(recordVersion)})',
      expectedFields: List.unmodifiable(
        specification == null ? const [] : allowedFields.toList()
          ..sort(),
      ),
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
  }) => BackupSchemaDiagnostics(
    validationStage: validationStage,
    store: null,
    recordType: null,
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

class BackupRecordValidationException implements Exception {
  final BackupSchemaDiagnostics diagnostics;

  const BackupRecordValidationException(this.diagnostics);

  @override
  String toString() =>
      'backup_schema_validation_failed at ${diagnostics.validationStage}';
}

/// Kept here to avoid exposing validation diagnostics through data models.
abstract final class BackupStoreRegistryNames {
  static String? storeFor(String section) => switch (section) {
    BackupSections.status => IndexedDbStoreNames.statusRecords,
    BackupSections.activity => IndexedDbStoreNames.activityRecords,
    BackupSections.food => IndexedDbStoreNames.foodRecords,
    BackupSections.training => IndexedDbStoreNames.trainingRecords,
    BackupSections.confirmations => IndexedDbStoreNames.dailyLogConfirmations,
    BackupSections.dailyAggregateRecords =>
      IndexedDbStoreNames.dailyAggregateRecords,
    BackupSections.morningBriefRecords =>
      IndexedDbStoreNames.morningBriefRecords,
    BackupSections.dailyDebriefRecords =>
      IndexedDbStoreNames.dailyDebriefRecords,
    _ => null,
  };
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
};
