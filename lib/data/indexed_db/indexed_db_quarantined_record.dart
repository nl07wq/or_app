class IndexedDbQuarantinedRecord {
  final String id;
  final String migrationId;
  final String sourceSection;
  final int sourceIndex;
  final Object? rawPayload;
  final String errorCode;
  final String? errorMessage;
  final DateTime detectedAt;

  IndexedDbQuarantinedRecord({
    required this.id,
    required this.migrationId,
    required this.sourceSection,
    required this.sourceIndex,
    required Object? rawPayload,
    required this.errorCode,
    this.errorMessage,
    required this.detectedAt,
  }) : rawPayload = _freeze(rawPayload);

  Map<String, Object?> toRecord() {
    return {
      'id': id,
      'migrationId': migrationId,
      'sourceSection': sourceSection,
      'sourceIndex': sourceIndex,
      'rawPayload': _copy(rawPayload),
      'errorCode': errorCode,
      if (errorMessage != null) 'errorMessage': errorMessage,
      'detectedAt': detectedAt.toUtc().toIso8601String(),
    };
  }

  factory IndexedDbQuarantinedRecord.fromRecord(Map<String, Object?> record) {
    return IndexedDbQuarantinedRecord(
      id: _requiredString(record, 'id'),
      migrationId: _requiredString(record, 'migrationId'),
      sourceSection: _requiredString(record, 'sourceSection'),
      sourceIndex: _requiredInt(record, 'sourceIndex'),
      rawPayload: record['rawPayload'],
      errorCode: _requiredString(record, 'errorCode'),
      errorMessage: _optionalString(record, 'errorMessage'),
      detectedAt: _requiredDate(record, 'detectedAt'),
    );
  }

  static String _requiredString(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid quarantined record $key.');
    }
    return value;
  }

  static String? _optionalString(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Invalid quarantined record $key.');
    }
    return value;
  }

  static int _requiredInt(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! int || value < 0) {
      throw FormatException('Invalid quarantined record $key.');
    }
    return value;
  }

  static DateTime _requiredDate(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String) {
      throw FormatException('Invalid quarantined record $key.');
    }
    final date = DateTime.tryParse(value);
    if (date == null) {
      throw FormatException('Invalid quarantined record $key.');
    }
    return date;
  }

  static Object? _freeze(Object? value) {
    if (value is Map) {
      return Map<String, Object?>.unmodifiable({
        for (final entry in value.entries)
          entry.key.toString(): _freeze(entry.value),
      });
    }
    if (value is Iterable) {
      return List<Object?>.unmodifiable(value.map(_freeze));
    }
    return value;
  }

  static Object? _copy(Object? value) {
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          entry.key.toString(): _copy(entry.value),
      };
    }
    if (value is Iterable) {
      return <Object?>[for (final item in value) _copy(item)];
    }
    return value;
  }
}
