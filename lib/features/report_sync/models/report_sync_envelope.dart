import '../services/report_sync_canonical_service.dart';

enum ReportSyncDirection {
  request('request'),
  response('response');

  const ReportSyncDirection(this.stableId);
  final String stableId;
}

enum ReportSyncExchangeType {
  training('training'),
  food('food'),
  morningBrief('morningBrief'),
  dailyDebrief('dailyDebrief');

  const ReportSyncExchangeType(this.stableId);
  final String stableId;
}

class ReportSyncEnvelope {
  static const formatId = 'operation-reboot-report-sync';
  static const currentEnvelopeVersion = 1;
  static const currentSchemaVersion = '1.0';

  final String format;
  final int envelopeVersion;
  final String schemaVersion;
  final ReportSyncDirection direction;
  final ReportSyncExchangeType exchangeType;
  final String exchangeId;
  final String? requestId;
  final String operationDate;
  final DateTime createdAt;
  final String? requestDigest;
  final String? confirmationDigest;
  final Map<String, Object?> payload;
  final String packageDigest;

  ReportSyncEnvelope({
    this.format = formatId,
    this.envelopeVersion = currentEnvelopeVersion,
    this.schemaVersion = currentSchemaVersion,
    required this.direction,
    required this.exchangeType,
    required this.exchangeId,
    this.requestId,
    required this.operationDate,
    required this.createdAt,
    this.requestDigest,
    required this.confirmationDigest,
    required Map<String, Object?> payload,
    required this.packageDigest,
  }) : payload = Map.unmodifiable(payload);

  Map<String, Object?> digestPayload() => {
    'format': format,
    'envelopeVersion': envelopeVersion,
    'schemaVersion': schemaVersion,
    'direction': direction.stableId,
    'exchangeType': exchangeType.stableId,
    'exchangeId': exchangeId,
    if (requestId != null) 'requestId': requestId,
    'operationDate': operationDate,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (requestDigest != null) 'requestDigest': requestDigest,
    'confirmationDigest': confirmationDigest,
    'payload': payload,
  };

  Map<String, Object?> toJson() => {
    ...digestPayload(),
    'packageDigest': packageDigest,
  };

  bool get hasValidPackageDigest =>
      ReportSyncCanonicalService.digest(digestPayload()) == packageDigest;
}
