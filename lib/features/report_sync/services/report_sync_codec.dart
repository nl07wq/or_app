import 'dart:convert';

import '../models/report_sync_envelope.dart';
import '../models/report_sync_issue.dart';
import 'report_sync_canonical_service.dart';

class ReportSyncCodec {
  static const _fields = {
    'format',
    'envelopeVersion',
    'schemaVersion',
    'direction',
    'exchangeType',
    'exchangeId',
    'requestId',
    'operationDate',
    'createdAt',
    'requestDigest',
    'confirmationDigest',
    'payload',
    'packageDigest',
  };

  const ReportSyncCodec();

  String encode(ReportSyncEnvelope envelope) =>
      ReportSyncCanonicalService.encode(envelope.toJson());

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
    if (json.keys.toSet().difference(_fields).isNotEmpty ||
        _fields.difference(json.keys.toSet()).isNotEmpty) {
      return _invalid('Envelope fields do not match schema 1.0.');
    }
    if (json['format'] != ReportSyncEnvelope.formatId ||
        json['envelopeVersion'] != ReportSyncEnvelope.currentEnvelopeVersion ||
        json['schemaVersion'] != ReportSyncEnvelope.currentSchemaVersion) {
      return _invalid('Unsupported REPORT SYNC schema.');
    }
    final direction = _enum(
      ReportSyncDirection.values,
      json['direction'],
      (v) => v.stableId,
    );
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
    final envelope = ReportSyncEnvelope(
      direction: direction,
      exchangeType: type,
      exchangeId: _string(json, 'exchangeId'),
      requestId: _string(json, 'requestId'),
      operationDate: _localDate(json['operationDate']),
      createdAt: createdAt,
      requestDigest: _digest(json['requestDigest'], 'requestDigest'),
      confirmationDigest: confirmation as String?,
      payload: Map<String, Object?>.from(payload),
      packageDigest: _digest(json['packageDigest'], 'packageDigest'),
    );
    if (!envelope.hasValidPackageDigest) {
      throw const ReportSyncException(
        ReportSyncIssueCode.integrityFailure,
        'packageDigest mismatch.',
      );
    }
    _validateConfirmationRule(envelope);
    _validatePayloadSections(envelope);
    if (envelope.direction == ReportSyncDirection.request &&
        ReportSyncCanonicalService.digest(envelope.payload) !=
            envelope.requestDigest) {
      throw const ReportSyncException(
        ReportSyncIssueCode.requestDigestMismatch,
        'requestDigest does not match the request payload.',
      );
    }
    return envelope;
  }

  ReportSyncEnvelope create({
    required ReportSyncDirection direction,
    required ReportSyncExchangeType exchangeType,
    required String exchangeId,
    required String requestId,
    required String operationDate,
    required DateTime createdAt,
    required String requestDigest,
    String? confirmationDigest,
    required Map<String, Object?> payload,
  }) {
    final base = ReportSyncEnvelope(
      direction: direction,
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
    final required =
        value.direction == ReportSyncDirection.response &&
        value.exchangeType == ReportSyncExchangeType.dailyDebrief;
    if (required != (value.confirmationDigest != null)) {
      _invalid(
        'confirmationDigest is only required for Daily Debrief responses.',
      );
    }
  }

  void _validatePayloadSections(ReportSyncEnvelope envelope) {
    final allowed = switch ((envelope.exchangeType, envelope.direction)) {
      (ReportSyncExchangeType.training, ReportSyncDirection.request) => const {
        'facts',
      },
      (ReportSyncExchangeType.training, ReportSyncDirection.response) => const {
        'session',
      },
      (ReportSyncExchangeType.food, ReportSyncDirection.request) => const {
        'facts',
      },
      (ReportSyncExchangeType.food, ReportSyncDirection.response) => const {
        'dailyMeal',
      },
      (ReportSyncExchangeType.morningBrief, ReportSyncDirection.request) =>
        const {
          'morningFact',
          'currentDailyState',
          'operationStatus',
          'commanderIntentCandidates',
          'trainingStatus',
          'foodStatus',
          'activityStatus',
          'carryOver',
        },
      (ReportSyncExchangeType.morningBrief, ReportSyncDirection.response) =>
        const {
          'model',
          'generatedAt',
          'situationAnalysis',
          'operationStatus',
          'commanderIntent',
          'argoComment',
          'strategicResourceDecision',
          'actions',
        },
      (ReportSyncExchangeType.dailyDebrief, ReportSyncDirection.request) =>
        const {
          'confirmation',
          'snapshot',
          'dns',
          'training',
          'food',
          'activity',
          'status',
          'operationSummary',
        },
      (ReportSyncExchangeType.dailyDebrief, ReportSyncDirection.response) =>
        const {
          'model',
          'generatedAt',
          'dailySummary',
          'commanderIntentEvaluation',
          'successes',
          'issues',
          'nutritionEvaluation',
          'activityEvaluation',
          'trainingEvaluation',
          'recoveryEvaluation',
          'carryover',
          'tomorrowConsiderations',
        },
    };
    final actual = envelope.payload.keys.toSet();
    if (actual.difference(allowed).isNotEmpty ||
        allowed.difference(actual).isNotEmpty) {
      _invalid('Payload sections do not match the exchange schema.');
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

  String _digest(Object? value, String key) {
    if (!ReportSyncCanonicalService.isDigest(value)) {
      return _invalid('$key is invalid.');
    }
    return value as String;
  }

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
