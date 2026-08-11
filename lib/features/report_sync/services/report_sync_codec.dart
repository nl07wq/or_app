import 'dart:convert';

import '../models/report_sync_envelope.dart';
import '../models/report_sync_issue.dart';
import 'report_sync_canonical_service.dart';
import 'report_sync_payload_registry.dart';

class ReportSyncCodec {
  static const _requiredFields = {
    'format',
    'envelopeVersion',
    'schemaVersion',
    'direction',
    'exchangeType',
    'exchangeId',
    'operationDate',
    'createdAt',
    'confirmationDigest',
    'payload',
    'packageDigest',
  };
  static const _optionalFields = {'requestId', 'requestDigest'};

  final ReportSyncPayloadRegistry? payloadRegistry;
  const ReportSyncCodec({this.payloadRegistry});
  ReportSyncPayloadRegistry get _effectivePayloadRegistry =>
      payloadRegistry ?? ReportSyncPayloadRegistry.standard();

  String encode(ReportSyncEnvelope envelope) {
    final json = envelope.toJson();
    if (_usesAppGeneratedDigest(envelope)) json['packageDigest'] = null;
    return ReportSyncCanonicalService.encode(json);
  }

  ReportSyncEnvelope decode(String input) {
    final Object? raw;
    try {
      raw = jsonDecode(input);
    } on FormatException catch (error) {
      throw ReportSyncException(
        ReportSyncIssueCode.schemaMismatch,
        error.message,
      );
    }
    if (raw is! Map) return _invalid('Root must be an object.');
    final json = Map<String, Object?>.from(raw);
    final fields = json.keys.toSet();
    if (fields.difference({
          ..._requiredFields,
          ..._optionalFields,
        }).isNotEmpty ||
        _requiredFields.difference(fields).isNotEmpty) {
      return _invalid('Envelope fields do not match schema 1.0.');
    }
    if (json['format'] != ReportSyncEnvelope.formatId ||
        json['envelopeVersion'] != ReportSyncEnvelope.currentEnvelopeVersion ||
        !ReportSyncEnvelope.supportedSchemaVersions.contains(
          json['schemaVersion'],
        )) {
      return _invalid('Unsupported REPORT SYNC schema.');
    }
    final direction = _enum(
      ReportSyncDirection.values,
      json['direction'],
      (v) => v.stableId,
    );
    if (direction == ReportSyncDirection.response &&
        (input.isEmpty || input.trim() != input)) {
      return _invalid('Response must contain exactly one JSON object.');
    }
    final type = _enum(
      ReportSyncExchangeType.values,
      json['exchangeType'],
      (v) => v.stableId,
    );
    final payload = json['payload'];
    if (payload is! Map) return _invalid('payload must be an object.');
    final confirmation = json['confirmationDigest'];
    if (confirmation != null &&
        !ReportSyncCanonicalService.isDigest(confirmation)) {
      return _invalid('confirmationDigest is invalid.');
    }
    final createdAt = DateTime.tryParse(_string(json, 'createdAt'));
    if (createdAt == null || !createdAt.isUtc) {
      return _invalid('createdAt must be UTC.');
    }
    final schemaVersion = json['schemaVersion'] as String;
    final appGeneratedDigest =
        schemaVersion == ReportSyncEnvelope.importSchemaVersion2 &&
        direction == ReportSyncDirection.response;
    final packageDigest = appGeneratedDigest
        ? _schema2PackageDigest(json['packageDigest'])
        : _digest(json['packageDigest'], 'packageDigest');
    var envelope = ReportSyncEnvelope(
      direction: direction,
      schemaVersion: schemaVersion,
      exchangeType: type,
      exchangeId: _string(json, 'exchangeId'),
      requestId: _optionalString(json, 'requestId'),
      operationDate: _localDate(json['operationDate']),
      createdAt: createdAt,
      requestDigest: _optionalDigest(json['requestDigest'], 'requestDigest'),
      confirmationDigest: confirmation as String?,
      payload: Map<String, Object?>.from(payload),
      packageDigest: packageDigest,
    );
    _validateConfirmationRule(envelope);
    _effectivePayloadRegistry.validate(envelope);
    _validatePayloadIdentity(envelope);
    if (envelope.direction == ReportSyncDirection.request &&
        (envelope.requestId == null ||
            envelope.requestDigest == null ||
            ReportSyncCanonicalService.digest(envelope.payload) !=
                envelope.requestDigest)) {
      throw const ReportSyncException(
        ReportSyncIssueCode.requestDigestMismatch,
        'requestDigest does not match the request payload.',
      );
    }
    if (appGeneratedDigest) {
      envelope = envelope.withPackageDigest(
        ReportSyncCanonicalService.digest(envelope.digestPayload()),
      );
    } else if (!envelope.hasValidPackageDigest) {
      throw const ReportSyncException(
        ReportSyncIssueCode.integrityFailure,
        'packageDigest mismatch.',
      );
    }
    return envelope;
  }

  ReportSyncEnvelope create({
    required ReportSyncDirection direction,
    required ReportSyncExchangeType exchangeType,
    required String exchangeId,
    String? requestId,
    required String operationDate,
    required DateTime createdAt,
    String? requestDigest,
    String? confirmationDigest,
    required Map<String, Object?> payload,
    String schemaVersion = ReportSyncEnvelope.currentSchemaVersion,
  }) {
    final base = ReportSyncEnvelope(
      direction: direction,
      schemaVersion: schemaVersion,
      exchangeType: exchangeType,
      exchangeId: exchangeId,
      requestId: requestId,
      operationDate: operationDate,
      createdAt: createdAt.toUtc(),
      requestDigest: requestDigest,
      confirmationDigest: confirmationDigest,
      payload: payload,
      packageDigest: '',
    );
    return ReportSyncEnvelope(
      direction: direction,
      schemaVersion: schemaVersion,
      exchangeType: exchangeType,
      exchangeId: exchangeId,
      requestId: requestId,
      operationDate: operationDate,
      createdAt: createdAt.toUtc(),
      requestDigest: requestDigest,
      confirmationDigest: confirmationDigest,
      payload: payload,
      packageDigest: ReportSyncCanonicalService.digest(base.digestPayload()),
    );
  }

  void _validateConfirmationRule(ReportSyncEnvelope value) {
    if (value.confirmationDigest != null) {
      _invalid('confirmationDigest is not supported by active exchanges.');
    }
  }

  void _validatePayloadIdentity(ReportSyncEnvelope envelope) {
    final payload = envelope.payload;
    if (payload['operationDate'] != envelope.operationDate) {
      _invalid('Payload operationDate does not match the envelope.');
    }
    if (envelope.direction == ReportSyncDirection.response) {
      final hasLegacyEnvelopeIdentity =
          envelope.requestId != null || envelope.requestDigest != null;
      final hasLegacyPayloadIdentity =
          payload.containsKey('requestId') ||
          payload.containsKey('requestDigest');
      if (hasLegacyEnvelopeIdentity != hasLegacyPayloadIdentity ||
          (hasLegacyEnvelopeIdentity &&
              (envelope.requestId == null ||
                  envelope.requestDigest == null ||
                  payload['requestId'] != envelope.requestId ||
                  payload['requestDigest'] != envelope.requestDigest))) {
        _invalid('Legacy request identity does not match the envelope.');
      }
    }
  }

  T _enum<T>(Iterable<T> values, Object? raw, String Function(T) id) {
    if (raw is! String) return _invalid('Unknown stable ID.');
    return values.firstWhere(
      (v) => id(v) == raw,
      orElse: () => _invalid('Unknown stable ID: $raw.'),
    );
  }

  String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) return _invalid('$key is invalid.');
    return value;
  }

  String? _optionalString(Map<String, Object?> json, String key) {
    if (!json.containsKey(key)) return null;
    return _string(json, key);
  }

  String _digest(Object? value, String key) {
    if (!ReportSyncCanonicalService.isDigest(value)) {
      return _invalid('$key is invalid.');
    }
    return value as String;
  }

  String? _optionalDigest(Object? value, String key) =>
      value == null ? null : _digest(value, key);

  String _schema2PackageDigest(Object? value) {
    if (value != null) {
      final preview = value.toString();
      throw ReportSyncException(
        ReportSyncIssueCode.schemaMismatch,
        'Schema 2.0 packageDigest must be null.',
        validationError: ReportSyncValidationError(
          code: 'invalidPackageDigestOwnership',
          jsonPath: r'$.packageDigest',
          message: 'Schema 2.0ではpackageDigestをnullにしてください。',
          expected: 'null',
          actualType: value.runtimeType.toString(),
          actualValuePreview: preview.length <= 64
              ? preview
              : preview.substring(0, 64),
        ),
      );
    }
    return '';
  }

  bool _usesAppGeneratedDigest(ReportSyncEnvelope envelope) =>
      envelope.schemaVersion == ReportSyncEnvelope.importSchemaVersion2 &&
      envelope.direction == ReportSyncDirection.response;

  String _localDate(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return _invalid('operationDate is invalid.');
    }
    final date = DateTime.tryParse('${value}T00:00:00Z');
    if (date == null || date.toIso8601String().substring(0, 10) != value) {
      return _invalid('operationDate is invalid.');
    }
    return value;
  }

  Never _invalid(String message) =>
      throw ReportSyncException(ReportSyncIssueCode.schemaMismatch, message);
}
