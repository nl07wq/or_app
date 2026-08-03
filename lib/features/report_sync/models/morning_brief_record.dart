import 'report_sync_record_utils.dart';

enum MorningBriefOperationStatus {
  green('green'),
  yellow('yellow'),
  red('red');

  const MorningBriefOperationStatus(this.stableId);
  final String stableId;
}

class MorningBriefSituationAnalysis {
  const MorningBriefSituationAnalysis({
    required this.body,
    required this.recovery,
    required this.condition,
    required this.work,
    required this.carryover,
    required this.overall,
  });

  static const fields = {
    'body',
    'recovery',
    'condition',
    'work',
    'carryover',
    'overall',
  };

  final String body;
  final String recovery;
  final String condition;
  final String work;
  final String carryover;
  final String overall;

  Map<String, Object?> toJson() => {
    'body': body,
    'recovery': recovery,
    'condition': condition,
    'work': work,
    'carryover': carryover,
    'overall': overall,
  };

  factory MorningBriefSituationAnalysis.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    return MorningBriefSituationAnalysis(
      body: ReportSyncRecordUtils.string(json, 'body'),
      recovery: ReportSyncRecordUtils.string(json, 'recovery'),
      condition: ReportSyncRecordUtils.string(json, 'condition'),
      work: ReportSyncRecordUtils.string(json, 'work'),
      carryover: ReportSyncRecordUtils.string(json, 'carryover'),
      overall: ReportSyncRecordUtils.string(json, 'overall'),
    );
  }

  String get displayText => [
    'BODY: $body',
    'RECOVERY: $recovery',
    'CONDITION: $condition',
    'WORK: $work',
    'CARRYOVER: $carryover',
    'OVERALL: $overall',
  ].join('\n');
}

class MorningBriefStrategicResourceDecision {
  const MorningBriefStrategicResourceDecision({
    required this.decision,
    required this.targetResource,
    required this.rationale,
    required this.execution,
  });

  static const fields = {
    'decision',
    'targetResource',
    'rationale',
    'execution',
  };

  final String decision;
  final String? targetResource;
  final String rationale;
  final String? execution;

  Map<String, Object?> toJson() => {
    'decision': decision,
    'targetResource': targetResource,
    'rationale': rationale,
    'execution': execution,
  };

  factory MorningBriefStrategicResourceDecision.fromJson(
    Map<String, Object?> json,
  ) {
    ReportSyncRecordUtils.exactFields(json, fields);
    return MorningBriefStrategicResourceDecision(
      decision: ReportSyncRecordUtils.string(json, 'decision'),
      targetResource: ReportSyncRecordUtils.nullableString(
        json,
        'targetResource',
      ),
      rationale: ReportSyncRecordUtils.string(json, 'rationale'),
      execution: ReportSyncRecordUtils.nullableString(json, 'execution'),
    );
  }

  String get displayText => [
    decision,
    if (targetResource != null) '対象資源: $targetResource',
    '理由: $rationale',
    if (execution != null) '実行: $execution',
  ].join('\n');
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
  static const legacyRecordVersion = 1;
  static const currentRecordVersion = 2;
  static const legacyFields = {
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
  static const currentFields = {
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
  };

  final String localDate;
  final int recordVersion;
  final String? requestId;
  final String? requestDigest;
  final String? sourceType;
  final String? sourceOperationDate;
  final String? sourceRecordId;
  final String? sourceDigest;
  final String responseDigest;
  final String? exchangeId;
  final DateTime generatedAt;
  final DateTime importedAt;
  final String? _legacySituationAnalysis;
  final MorningBriefSituationAnalysis? situationAnalysisV2;
  final MorningBriefOperationStatus operationStatus;
  final String commanderIntent;
  final String? argoComment;
  final String? operatingPolicy;
  final String? _legacyStrategicResourceDecision;
  final MorningBriefStrategicResourceDecision? strategicResourceDecisionV2;
  final List<MorningBriefAction> actions;
  final DateTime createdAt;
  final DateTime updatedAt;

  MorningBriefRecord({
    required this.localDate,
    this.recordVersion = legacyRecordVersion,
    required this.requestId,
    required this.requestDigest,
    required this.responseDigest,
    required this.generatedAt,
    required this.importedAt,
    required String situationAnalysis,
    required this.operationStatus,
    required this.commanderIntent,
    required this.argoComment,
    required String strategicResourceDecision,
    required Iterable<MorningBriefAction> actions,
    required this.createdAt,
    required this.updatedAt,
  }) : sourceType = null,
       sourceOperationDate = null,
       sourceRecordId = null,
       sourceDigest = null,
       exchangeId = null,
       _legacySituationAnalysis = situationAnalysis,
       situationAnalysisV2 = null,
       operatingPolicy = null,
       _legacyStrategicResourceDecision = strategicResourceDecision,
       strategicResourceDecisionV2 = null,
       actions = List.unmodifiable(actions) {
    if (recordVersion != legacyRecordVersion) {
      throw const FormatException('Legacy Morning Brief version must be 1.');
    }
    if (requestId == null ||
        requestId!.isEmpty ||
        requestDigest == null ||
        requestDigest!.isEmpty ||
        argoComment == null ||
        argoComment!.isEmpty) {
      throw const FormatException('Legacy Morning Brief fields are invalid.');
    }
    _validateTimestamps();
  }

  MorningBriefRecord.v2({
    required this.localDate,
    required this.sourceType,
    required this.sourceOperationDate,
    required this.sourceRecordId,
    required this.sourceDigest,
    required this.responseDigest,
    required this.exchangeId,
    required this.generatedAt,
    required this.importedAt,
    required this.situationAnalysisV2,
    required this.operatingPolicy,
    required this.strategicResourceDecisionV2,
    required this.operationStatus,
    required this.commanderIntent,
    required Iterable<MorningBriefAction> actions,
    required this.createdAt,
    required this.updatedAt,
  }) : recordVersion = currentRecordVersion,
       requestId = null,
       requestDigest = null,
       _legacySituationAnalysis = null,
       argoComment = null,
       _legacyStrategicResourceDecision = null,
       actions = List.unmodifiable(actions) {
    if (sourceType != 'status' ||
        sourceOperationDate != localDate ||
        sourceRecordId == null ||
        sourceRecordId!.isEmpty ||
        sourceDigest == null ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sourceDigest!) ||
        exchangeId == null ||
        exchangeId!.isEmpty ||
        situationAnalysisV2 == null ||
        operatingPolicy == null ||
        operatingPolicy!.isEmpty ||
        strategicResourceDecisionV2 == null) {
      throw const FormatException('Morning Brief source identity is invalid.');
    }
    _validateTimestamps();
  }

  bool get isV2 => recordVersion == currentRecordVersion;

  String get situationAnalysis =>
      _legacySituationAnalysis ?? situationAnalysisV2!.displayText;

  String get strategicResourceDecision =>
      _legacyStrategicResourceDecision ??
      strategicResourceDecisionV2!.displayText;

  void _validateTimestamps() {
    if (updatedAt.isBefore(createdAt)) {
      throw const FormatException('updatedAt precedes createdAt.');
    }
  }

  Map<String, Object?> toRecord() => isV2
      ? {
          'localDate': localDate,
          'recordVersion': recordVersion,
          'sourceType': sourceType,
          'sourceOperationDate': sourceOperationDate,
          'sourceRecordId': sourceRecordId,
          'sourceDigest': sourceDigest,
          'responseDigest': responseDigest,
          'exchangeId': exchangeId,
          'generatedAt': generatedAt.toUtc().toIso8601String(),
          'importedAt': importedAt.toUtc().toIso8601String(),
          'situationAnalysis': situationAnalysisV2!.toJson(),
          'operatingPolicy': operatingPolicy,
          'strategicResourceDecision': strategicResourceDecisionV2!.toJson(),
          'operationStatus': operationStatus.stableId,
          'commanderIntent': commanderIntent,
          'actions': [for (final action in actions) action.toJson()],
          'createdAt': createdAt.toUtc().toIso8601String(),
          'updatedAt': updatedAt.toUtc().toIso8601String(),
        }
      : {
          'localDate': localDate,
          'recordVersion': recordVersion,
          'requestId': requestId,
          'requestDigest': requestDigest,
          'responseDigest': responseDigest,
          'generatedAt': generatedAt.toUtc().toIso8601String(),
          'importedAt': importedAt.toUtc().toIso8601String(),
          'situationAnalysis': _legacySituationAnalysis,
          'operationStatus': operationStatus.stableId,
          'commanderIntent': commanderIntent,
          'argoComment': argoComment,
          'strategicResourceDecision': _legacyStrategicResourceDecision,
          'actions': [for (final action in actions) action.toJson()],
          'createdAt': createdAt.toUtc().toIso8601String(),
          'updatedAt': updatedAt.toUtc().toIso8601String(),
        };

  factory MorningBriefRecord.fromRecord(Map<String, Object?> json) {
    final version = json['recordVersion'];
    if (version == legacyRecordVersion) return _fromLegacyRecord(json);
    if (version == currentRecordVersion) return _fromCurrentRecord(json);
    throw const FormatException('Unsupported Morning Brief version.');
  }

  static MorningBriefRecord _fromLegacyRecord(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, legacyFields);
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
      operationStatus: _status(json),
      commanderIntent: ReportSyncRecordUtils.string(json, 'commanderIntent'),
      argoComment: ReportSyncRecordUtils.string(json, 'argoComment'),
      strategicResourceDecision: ReportSyncRecordUtils.string(
        json,
        'strategicResourceDecision',
      ),
      actions: _actions(json),
      createdAt: ReportSyncRecordUtils.date(json, 'createdAt'),
      updatedAt: ReportSyncRecordUtils.date(json, 'updatedAt'),
    );
  }

  static MorningBriefRecord _fromCurrentRecord(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, currentFields);
    return MorningBriefRecord.v2(
      localDate: ReportSyncRecordUtils.localDate(json, 'localDate'),
      sourceType: ReportSyncRecordUtils.string(json, 'sourceType'),
      sourceOperationDate: ReportSyncRecordUtils.localDate(
        json,
        'sourceOperationDate',
      ),
      sourceRecordId: ReportSyncRecordUtils.string(json, 'sourceRecordId'),
      sourceDigest: ReportSyncRecordUtils.digest(json, 'sourceDigest'),
      responseDigest: ReportSyncRecordUtils.digest(json, 'responseDigest'),
      exchangeId: ReportSyncRecordUtils.string(json, 'exchangeId'),
      generatedAt: ReportSyncRecordUtils.date(json, 'generatedAt'),
      importedAt: ReportSyncRecordUtils.date(json, 'importedAt'),
      situationAnalysisV2: MorningBriefSituationAnalysis.fromJson(
        Map<String, Object?>.from(json['situationAnalysis'] as Map),
      ),
      operatingPolicy: ReportSyncRecordUtils.string(json, 'operatingPolicy'),
      strategicResourceDecisionV2:
          MorningBriefStrategicResourceDecision.fromJson(
            Map<String, Object?>.from(json['strategicResourceDecision'] as Map),
          ),
      operationStatus: _status(json),
      commanderIntent: ReportSyncRecordUtils.string(json, 'commanderIntent'),
      actions: _actions(json),
      createdAt: ReportSyncRecordUtils.date(json, 'createdAt'),
      updatedAt: ReportSyncRecordUtils.date(json, 'updatedAt'),
    );
  }

  static MorningBriefOperationStatus _status(Map<String, Object?> json) {
    final raw = ReportSyncRecordUtils.string(json, 'operationStatus');
    return MorningBriefOperationStatus.values.firstWhere(
      (value) => value.stableId == raw,
      orElse: () => throw const FormatException('Unknown operationStatus.'),
    );
  }

  static List<MorningBriefAction> _actions(Map<String, Object?> json) {
    final values = json['actions'];
    if (values is! List || values.any((value) => value is! Map)) {
      throw const FormatException('actions is invalid.');
    }
    return [
      for (final value in values)
        MorningBriefAction.fromJson(Map<String, Object?>.from(value as Map)),
    ];
  }
}
