import '../models/orlo_sync_models.dart';
import 'orlo_sync_registry.dart';

class OrloSyncValidationOutput {
  const OrloSyncValidationOutput({
    required this.envelope,
    required this.issues,
  });

  final OrloSyncEnvelope? envelope;
  final List<SyncIssue> issues;
}

class OrloSyncValidator {
  const OrloSyncValidator(this.registry);

  final OrloSyncTypeRegistry registry;

  static const _topLevelFields = {
    'format',
    'envelopeVersion',
    'schemaVersion',
    'dataType',
    'packageId',
    'idempotencyKey',
    'source',
    'operationDate',
    'payload',
  };
  static const _sourceFields = {
    'type',
    'generatedAt',
    'producer',
    'producerVersion',
  };

  OrloSyncValidationOutput validate(Map<String, Object?> json) {
    final issues = <SyncIssue>[];
    _rejectUnknown(json, _topLevelFields, r'$', issues);
    final format = _string(json, 'format', r'$.format', issues);
    final envelopeVersion = _integer(
      json,
      'envelopeVersion',
      r'$.envelopeVersion',
      issues,
    );
    final schemaVersion = _string(
      json,
      'schemaVersion',
      r'$.schemaVersion',
      issues,
    );
    final dataType = _string(json, 'dataType', r'$.dataType', issues);
    final packageId = _string(json, 'packageId', r'$.packageId', issues);
    final idempotencyKey = _string(
      json,
      'idempotencyKey',
      r'$.idempotencyKey',
      issues,
    );
    final sourceJson = _map(json, 'source', r'$.source', issues);
    final operationDate = _nullableString(
      json,
      'operationDate',
      r'$.operationDate',
      issues,
    );
    final payload = _map(json, 'payload', r'$.payload', issues);

    if (format != null && format != OrloSyncEnvelope.format) {
      issues.add(_blocking('invalidFormat', r'$.format', 'formatが不正です。'));
    }
    if (envelopeVersion != null &&
        envelopeVersion != OrloSyncEnvelope.currentEnvelopeVersion) {
      issues.add(
        _blocking(
          'unsupportedVersion',
          r'$.envelopeVersion',
          '未対応のEnvelope Versionです。',
        ),
      );
    }
    final definition = dataType == null ? null : registry.find(dataType);
    if (dataType != null && definition == null) {
      issues.add(
        _blocking('unknownDataType', r'$.dataType', '未対応のData Typeです。'),
      );
    }
    if (schemaVersion != null &&
        definition != null &&
        schemaVersion != definition.schemaVersion) {
      issues.add(
        _blocking(
          'unsupportedVersion',
          r'$.schemaVersion',
          '未対応のData Type Schema Versionです。',
        ),
      );
    }
    if (definition != null && !definition.isAvailable) {
      issues.add(
        _blocking(
          'adapterUnavailable',
          r'$.dataType',
          '${definition.displayName}はCOMING LATERです。',
        ),
      );
    }
    if (operationDate != null && !_isLocalDate(operationDate)) {
      issues.add(
        _blocking(
          'invalidOperationDate',
          r'$.operationDate',
          'Operation Dateが不正です。',
        ),
      );
    }

    OrloSyncSource? source;
    if (sourceJson != null) {
      _rejectUnknown(sourceJson, _sourceFields, r'$.source', issues);
      final type = _string(sourceJson, 'type', r'$.source.type', issues);
      final generatedAtText = _string(
        sourceJson,
        'generatedAt',
        r'$.source.generatedAt',
        issues,
      );
      final producer = _string(
        sourceJson,
        'producer',
        r'$.source.producer',
        issues,
      );
      final producerVersion = _nullableString(
        sourceJson,
        'producerVersion',
        r'$.source.producerVersion',
        issues,
      );
      final generatedAt = generatedAtText == null
          ? null
          : DateTime.tryParse(generatedAtText);
      if (generatedAtText != null && generatedAt == null) {
        issues.add(
          _blocking('invalidDateTime', r'$.source.generatedAt', '生成日時が不正です。'),
        );
      }
      if (type != null && generatedAt != null && producer != null) {
        source = OrloSyncSource(
          type: type,
          generatedAt: generatedAt,
          producer: producer,
          producerVersion: producerVersion,
        );
      }
    }

    if (issues.any((issue) => issue.code != 'adapterUnavailable')) {
      return OrloSyncValidationOutput(envelope: null, issues: issues);
    }
    return OrloSyncValidationOutput(
      envelope: OrloSyncEnvelope(
        envelopeVersion: envelopeVersion!,
        schemaVersion: schemaVersion!,
        dataType: dataType!,
        packageId: packageId!,
        idempotencyKey: idempotencyKey!,
        source: source!,
        operationDate: operationDate,
        payload: payload!,
      ),
      issues: issues,
    );
  }

  static String? _string(
    Map<String, Object?> json,
    String key,
    String path,
    List<SyncIssue> issues,
  ) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      issues.add(
        _blocking(
          json.containsKey(key) ? 'invalidType' : 'missingField',
          path,
          '必須文字列が不正です。',
        ),
      );
      return null;
    }
    return value;
  }

  static String? _nullableString(
    Map<String, Object?> json,
    String key,
    String path,
    List<SyncIssue> issues,
  ) {
    if (!json.containsKey(key)) {
      issues.add(_blocking('missingField', path, '必須Fieldがありません。'));
      return null;
    }
    final value = json[key];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) {
      issues.add(_blocking('invalidType', path, '文字列またはnullが必要です。'));
      return null;
    }
    return value;
  }

  static int? _integer(
    Map<String, Object?> json,
    String key,
    String path,
    List<SyncIssue> issues,
  ) {
    final value = json[key];
    if (value is! int) {
      issues.add(
        _blocking(
          json.containsKey(key) ? 'invalidType' : 'missingField',
          path,
          '整数が必要です。',
        ),
      );
      return null;
    }
    return value;
  }

  static Map<String, Object?>? _map(
    Map<String, Object?> json,
    String key,
    String path,
    List<SyncIssue> issues,
  ) {
    final value = json[key];
    if (value is! Map) {
      issues.add(
        _blocking(
          json.containsKey(key) ? 'invalidType' : 'missingField',
          path,
          'Objectが必要です。',
        ),
      );
      return null;
    }
    return Map<String, Object?>.from(value);
  }

  static void _rejectUnknown(
    Map<String, Object?> json,
    Set<String> allowed,
    String path,
    List<SyncIssue> issues,
  ) {
    for (final key in json.keys.where((key) => !allowed.contains(key))) {
      issues.add(_blocking('unknownField', '$path.$key', '未知Fieldは使用できません。'));
    }
  }

  static bool _isLocalDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return false;
    final parsed = DateTime.tryParse('${value}T00:00:00Z');
    return parsed != null && parsed.toIso8601String().startsWith(value);
  }

  static SyncIssue _blocking(String code, String path, String message) =>
      SyncIssue(
        code: code,
        path: path,
        message: message,
        severity: SyncIssueSeverity.blockingError,
      );
}
