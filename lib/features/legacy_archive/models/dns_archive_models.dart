enum DnsParseStatus { parsed, parsedWithWarnings, blocked }

enum DnsWarningCode {
  estimatedValue,
  rangeValue,
  missingSection,
  missingField,
  unrecognizedLine,
  duplicateOperationDate,
  invalidDate,
  invalidNumber,
  inconsistentTotals,
  unsupportedSection,
  recordBoundaryUnclear,
}

class DnsWarning {
  final DnsWarningCode code;
  final String message;
  final String? field;
  const DnsWarning({required this.code, required this.message, this.field});

  Map<String, Object?> toJson() => {
    'code': code.name,
    'message': message,
    if (field != null) 'field': field,
  };

  factory DnsWarning.fromJson(Map<String, Object?> json) {
    const allowed = {'code', 'message', 'field'};
    if (json.keys.toSet().difference(allowed).isNotEmpty ||
        !json.keys.toSet().containsAll(const {'code', 'message'})) {
      throw const FormatException('Unknown or missing warning field.');
    }
    return DnsWarning(
      code: DnsWarningCode.values.byName(_string(json['code'], 'code')),
      message: _string(json['message'], 'message'),
      field: _nullableString(json['field'], 'field'),
    );
  }
}

sealed class DnsNumericValue {
  final bool isEstimated;
  const DnsNumericValue(this.isEstimated);
  Map<String, Object?> toJson();

  factory DnsNumericValue.fromJson(Map<String, Object?> json) {
    if (json.keys.toSet().containsAll(const {'value', 'isEstimated'})) {
      _exact(json, const {'value', 'isEstimated'});
      return DnsSingleValue(
        _number(json['value'], 'value'),
        _boolean(json['isEstimated'], 'isEstimated'),
      );
    }
    _exact(json, const {'minimum', 'maximum', 'isEstimated'});
    final minimum = _number(json['minimum'], 'minimum');
    final maximum = _number(json['maximum'], 'maximum');
    if (maximum < minimum) throw const FormatException('Invalid range.');
    return DnsRangeValue(
      minimum,
      maximum,
      _boolean(json['isEstimated'], 'isEstimated'),
    );
  }
}

class DnsSingleValue extends DnsNumericValue {
  final double value;
  const DnsSingleValue(this.value, bool isEstimated) : super(isEstimated);
  @override
  Map<String, Object?> toJson() => {'value': value, 'isEstimated': isEstimated};
}

class DnsRangeValue extends DnsNumericValue {
  final double minimum;
  final double maximum;
  const DnsRangeValue(this.minimum, this.maximum, bool isEstimated)
    : super(isEstimated);
  @override
  Map<String, Object?> toJson() => {
    'minimum': minimum,
    'maximum': maximum,
    'isEstimated': isEstimated,
  };
}

class DnsSourceRecord {
  final String sourceRecordId;
  final int sourceOrder;
  final String rawText;
  const DnsSourceRecord({
    required this.sourceRecordId,
    required this.sourceOrder,
    required this.rawText,
  });
  Map<String, Object?> toJson() => {
    'sourceRecordId': sourceRecordId,
    'sourceOrder': sourceOrder,
    'reportType': 'dns',
    'rawText': rawText,
  };
}

class DnsSourcePackage {
  static const format = 'operation-reboot-dns-source';
  final String sourcePackageId;
  final DateTime createdAt;
  final List<DnsSourceRecord> records;
  const DnsSourcePackage({
    required this.sourcePackageId,
    required this.createdAt,
    required this.records,
  });
  Map<String, Object?> toJson() => {
    'format': format,
    'envelopeVersion': 1,
    'schemaVersion': '1.0',
    'sourceType': 'dnsArchive',
    'sourcePackageId': sourcePackageId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'records': records.map((record) => record.toJson()).toList(),
  };
}

class DnsNormalizedRecord {
  final String sourceRecordId;
  final String? operationDate;
  final DnsParseStatus parseStatus;
  final Map<String, Object?> data;
  final List<DnsWarning> warnings;
  final List<String> unmappedFragments;
  const DnsNormalizedRecord({
    required this.sourceRecordId,
    required this.operationDate,
    required this.parseStatus,
    required this.data,
    required this.warnings,
    required this.unmappedFragments,
  });
  Map<String, Object?> toJson() => {
    'sourceRecordId': sourceRecordId,
    'operationDate': operationDate,
    'parseStatus': parseStatus.name,
    'data': data,
    'warnings': warnings.map((warning) => warning.toJson()).toList(),
    'unmappedFragments': unmappedFragments,
  };
}

class DnsNormalizedPackage {
  static const format = 'operation-reboot-dns-normalized';
  final String sourcePackageId;
  final DateTime generatedAt;
  final List<DnsNormalizedRecord> records;
  const DnsNormalizedPackage({
    required this.sourcePackageId,
    required this.generatedAt,
    required this.records,
  });
  Map<String, Object?> toJson() => {
    'format': format,
    'envelopeVersion': 1,
    'schemaVersion': '1.0',
    'sourceType': 'dnsArchive',
    'sourcePackageId': sourcePackageId,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'records': records.map((record) => record.toJson()).toList(),
  };
}

class LegacyDailySummaryRecord {
  static const recordVersion = 1;
  final String localDate;
  final String sourceRecordId;
  final String sourcePackageId;
  final Map<String, Object?>? body;
  final Map<String, Object?>? nutrition;
  final Map<String, Object?>? hydration;
  final Map<String, Object?>? activity;
  final Map<String, Object?>? work;
  final Map<String, Object?>? operation;
  final List<DnsWarning> warnings;
  final List<String> unmappedFragments;
  final String sourceTextDigest;
  final DateTime createdAt;
  final DateTime importedAt;

  const LegacyDailySummaryRecord({
    required this.localDate,
    required this.sourceRecordId,
    required this.sourcePackageId,
    this.body,
    this.nutrition,
    this.hydration,
    this.activity,
    this.work,
    this.operation,
    required this.warnings,
    required this.unmappedFragments,
    required this.sourceTextDigest,
    required this.createdAt,
    required this.importedAt,
  });

  Map<String, Object?> toRecord() => {
    'localDate': localDate,
    'recordVersion': recordVersion,
    'sourceType': 'dnsArchive',
    'sourceRecordId': sourceRecordId,
    'sourcePackageId': sourcePackageId,
    'body': body,
    'nutrition': nutrition,
    'hydration': hydration,
    'activity': activity,
    'work': work,
    'operation': operation,
    'warnings': warnings.map((warning) => warning.toJson()).toList(),
    'unmappedFragments': unmappedFragments,
    'sourceTextDigest': sourceTextDigest,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'importedAt': importedAt.toUtc().toIso8601String(),
  };

  factory LegacyDailySummaryRecord.fromRecord(Map<String, Object?> json) {
    _exact(json, const {
      'localDate',
      'recordVersion',
      'sourceType',
      'sourceRecordId',
      'sourcePackageId',
      'body',
      'nutrition',
      'hydration',
      'activity',
      'work',
      'operation',
      'warnings',
      'unmappedFragments',
      'sourceTextDigest',
      'createdAt',
      'importedAt',
    });
    if (json['recordVersion'] != recordVersion ||
        json['sourceType'] != 'dnsArchive') {
      throw const FormatException('Unsupported legacy summary record.');
    }
    return LegacyDailySummaryRecord(
      localDate: _date(json['localDate'], 'localDate'),
      sourceRecordId: _string(json['sourceRecordId'], 'sourceRecordId'),
      sourcePackageId: _string(json['sourcePackageId'], 'sourcePackageId'),
      body: _nullableMap(json['body'], 'body'),
      nutrition: _nullableMap(json['nutrition'], 'nutrition'),
      hydration: _nullableMap(json['hydration'], 'hydration'),
      activity: _nullableMap(json['activity'], 'activity'),
      work: _nullableMap(json['work'], 'work'),
      operation: _nullableMap(json['operation'], 'operation'),
      warnings: _list(
        json['warnings'],
        'warnings',
      ).map((value) => DnsWarning.fromJson(_map(value, 'warning'))).toList(),
      unmappedFragments: _list(
        json['unmappedFragments'],
        'unmappedFragments',
      ).map((value) => _string(value, 'fragment')).toList(),
      sourceTextDigest: _digest(json['sourceTextDigest'], 'sourceTextDigest'),
      createdAt: _utc(json['createdAt'], 'createdAt'),
      importedAt: _utc(json['importedAt'], 'importedAt'),
    );
  }
}

enum DnsPreviewDisposition { create, noChange, conflict, blocked }

class DnsConversionPreview {
  final String sourcePackageId;
  final int sourceRecordCount;
  final int parsedCount;
  final int warningCount;
  final int blockingCount;
  final int createCount;
  final int noChangeCount;
  final int conflictCount;
  final String? operationDateRange;
  final Map<String, int> missingFieldSummary;
  final List<DnsWarning> warnings;
  final List<String> blockingIssues;
  final List<LegacyDailySummaryRecord> records;
  const DnsConversionPreview({
    required this.sourcePackageId,
    required this.sourceRecordCount,
    required this.parsedCount,
    required this.warningCount,
    required this.blockingCount,
    required this.createCount,
    required this.noChangeCount,
    required this.conflictCount,
    required this.operationDateRange,
    required this.missingFieldSummary,
    required this.warnings,
    required this.blockingIssues,
    required this.records,
  });
  bool get canApply => blockingCount == 0 && conflictCount == 0;
}

void _exact(Map<String, Object?> json, Set<String> fields) {
  if (json.keys.toSet().difference(fields).isNotEmpty ||
      fields.difference(json.keys.toSet()).isNotEmpty) {
    throw const FormatException('Unknown or missing field.');
  }
}

Map<String, Object?> _map(Object? value, String name) {
  if (value is! Map) throw FormatException('$name must be an object.');
  return Map<String, Object?>.from(value);
}

Map<String, Object?>? _nullableMap(Object? value, String name) =>
    value == null ? null : _map(value, name);
List<Object?> _list(Object? value, String name) {
  if (value is! List) throw FormatException('$name must be an array.');
  return value.cast<Object?>();
}

String _string(Object? value, String name) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$name is invalid.');
  }
  return value;
}

String? _nullableString(Object? value, String name) =>
    value == null ? null : _string(value, name);
bool _boolean(Object? value, String name) {
  if (value is! bool) throw FormatException('$name is invalid.');
  return value;
}

double _number(Object? value, String name) {
  if (value is! num || !value.isFinite) {
    throw FormatException('$name is invalid.');
  }
  return value.toDouble();
}

String _date(Object? value, String name) {
  final text = _string(value, name);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
      DateTime.tryParse(
            '${text}T00:00:00Z',
          )?.toIso8601String().substring(0, 10) !=
          text) {
    throw FormatException('$name is invalid.');
  }
  return text;
}

DateTime _utc(Object? value, String name) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('$name must be UTC.');
  }
  return parsed;
}

String _digest(Object? value, String name) {
  final text = _string(value, name);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(text)) {
    throw FormatException('$name is invalid.');
  }
  return text;
}
