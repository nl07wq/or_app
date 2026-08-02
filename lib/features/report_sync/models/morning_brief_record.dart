import 'report_sync_record_utils.dart';

enum MorningBriefOperationStatus {
  green('green'),
  yellow('yellow'),
  red('red');

  const MorningBriefOperationStatus(this.stableId);
  final String stableId;
}

class MorningBriefAction {
  final String actionId;
  final String text;
  final String priority;
  const MorningBriefAction({
    required this.actionId,
    required this.text,
    required this.priority,
  });

  Map<String, Object?> toJson() => {
    'actionId': actionId,
    'text': text,
    'priority': priority,
  };
  factory MorningBriefAction.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, const {
      'actionId',
      'text',
      'priority',
    });
    return MorningBriefAction(
      actionId: ReportSyncRecordUtils.string(json, 'actionId'),
      text: ReportSyncRecordUtils.string(json, 'text'),
      priority: ReportSyncRecordUtils.string(json, 'priority'),
    );
  }
}

class MorningBriefRecord {
  static const currentRecordVersion = 1;
  static const fields = {
    'localDate',
    'recordVersion',
    'requestId',
    'requestDigest',
    'responseDigest',
    'generatedAt',
    'importedAt',
    'situationAnalysis',
    'operationStatus',
    'commanderIntent',
    'argoComment',
    'strategicResourceDecision',
    'actions',
    'createdAt',
    'updatedAt',
  };
  final String localDate;
  final int recordVersion;
  final String requestId;
  final String requestDigest;
  final String responseDigest;
  final DateTime generatedAt;
  final DateTime importedAt;
  final String situationAnalysis;
  final MorningBriefOperationStatus operationStatus;
  final String commanderIntent;
  final String argoComment;
  final String strategicResourceDecision;
  final List<MorningBriefAction> actions;
  final DateTime createdAt;
  final DateTime updatedAt;

  MorningBriefRecord({
    required this.localDate,
    this.recordVersion = currentRecordVersion,
    required this.requestId,
    required this.requestDigest,
    required this.responseDigest,
    required this.generatedAt,
    required this.importedAt,
    required this.situationAnalysis,
    required this.operationStatus,
    required this.commanderIntent,
    required this.argoComment,
    required this.strategicResourceDecision,
    required Iterable<MorningBriefAction> actions,
    required this.createdAt,
    required this.updatedAt,
  }) : actions = List.unmodifiable(actions) {
    if (updatedAt.isBefore(createdAt)) {
      throw const FormatException('updatedAt precedes createdAt.');
    }
  }

  Map<String, Object?> toRecord() => {
    'localDate': localDate,
    'recordVersion': recordVersion,
    'requestId': requestId,
    'requestDigest': requestDigest,
    'responseDigest': responseDigest,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'importedAt': importedAt.toUtc().toIso8601String(),
    'situationAnalysis': situationAnalysis,
    'operationStatus': operationStatus.stableId,
    'commanderIntent': commanderIntent,
    'argoComment': argoComment,
    'strategicResourceDecision': strategicResourceDecision,
    'actions': [for (final action in actions) action.toJson()],
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory MorningBriefRecord.fromRecord(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    if (json['recordVersion'] != currentRecordVersion) {
      throw const FormatException('Unsupported Morning Brief version.');
    }
    final actions = json['actions'];
    if (actions is! List || actions.any((value) => value is! Map)) {
      throw const FormatException('actions is invalid.');
    }
    final statusRaw = ReportSyncRecordUtils.string(json, 'operationStatus');
    final status = MorningBriefOperationStatus.values.firstWhere(
      (v) => v.stableId == statusRaw,
      orElse: () => throw const FormatException('Unknown operationStatus.'),
    );
    return MorningBriefRecord(
      localDate: ReportSyncRecordUtils.localDate(json, 'localDate'),
      requestId: ReportSyncRecordUtils.string(json, 'requestId'),
      requestDigest: ReportSyncRecordUtils.digest(json, 'requestDigest'),
      responseDigest: ReportSyncRecordUtils.digest(json, 'responseDigest'),
      generatedAt: ReportSyncRecordUtils.date(json, 'generatedAt'),
      importedAt: ReportSyncRecordUtils.date(json, 'importedAt'),
      situationAnalysis: ReportSyncRecordUtils.string(
        json,
        'situationAnalysis',
      ),
      operationStatus: status,
      commanderIntent: ReportSyncRecordUtils.string(json, 'commanderIntent'),
      argoComment: ReportSyncRecordUtils.string(json, 'argoComment'),
      strategicResourceDecision: ReportSyncRecordUtils.string(
        json,
        'strategicResourceDecision',
      ),
      actions: [
        for (final value in actions)
          MorningBriefAction.fromJson(Map<String, Object?>.from(value as Map)),
      ],
      createdAt: ReportSyncRecordUtils.date(json, 'createdAt'),
      updatedAt: ReportSyncRecordUtils.date(json, 'updatedAt'),
    );
  }
}
