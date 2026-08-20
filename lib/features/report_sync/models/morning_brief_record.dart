import 'report_sync_record_utils.dart';

enum MorningBriefOperationStatus {
  green('green'),
  yellow('yellow'),
  red('red');

  const MorningBriefOperationStatus(this.stableId);
  final String stableId;
}

class MorningBriefSectionDisplay {
  const MorningBriefSectionDisplay({
    required this.primaryText,
    required this.supportingText,
  });

  static const fields = {'primaryText', 'supportingText'};

  final String primaryText;
  final String? supportingText;

  Map<String, Object?> toJson() => {
    'primaryText': primaryText,
    'supportingText': supportingText,
  };

  factory MorningBriefSectionDisplay.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    return MorningBriefSectionDisplay(
      primaryText: ReportSyncRecordUtils.string(json, 'primaryText'),
      supportingText: ReportSyncRecordUtils.nullableString(
        json,
        'supportingText',
      ),
    );
  }
}

class MorningBriefSituationAnalysis {
  const MorningBriefSituationAnalysis({
    required this.body,
    required this.recovery,
    required this.condition,
    required this.work,
    required this.carryover,
    required this.overall,
    this.bodyDisplay,
    this.recoveryDisplay,
    this.conditionDisplay,
    this.workDisplay,
  });

  static const requiredFields = {
    'body',
    'recovery',
    'condition',
    'work',
    'carryover',
    'overall',
  };
  static const fields = {
    ...requiredFields,
    'bodyDisplay',
    'recoveryDisplay',
    'conditionDisplay',
    'workDisplay',
  };

  final String body;
  final String recovery;
  final String condition;
  final String work;
  final String carryover;
  final String overall;
  final MorningBriefSectionDisplay? bodyDisplay;
  final MorningBriefSectionDisplay? recoveryDisplay;
  final MorningBriefSectionDisplay? conditionDisplay;
  final MorningBriefSectionDisplay? workDisplay;

  Map<String, Object?> toJson() => {
    'body': body,
    'recovery': recovery,
    'condition': condition,
    'work': work,
    'carryover': carryover,
    'overall': overall,
    if (bodyDisplay != null) 'bodyDisplay': bodyDisplay!.toJson(),
    if (recoveryDisplay != null) 'recoveryDisplay': recoveryDisplay!.toJson(),
    if (conditionDisplay != null)
      'conditionDisplay': conditionDisplay!.toJson(),
    if (workDisplay != null) 'workDisplay': workDisplay!.toJson(),
  };

  factory MorningBriefSituationAnalysis.fromJson(Map<String, Object?> json) {
    final actualFields = json.keys.toSet();
    if (actualFields.difference(fields).isNotEmpty ||
        requiredFields.difference(actualFields).isNotEmpty) {
      throw const FormatException(
        'Morning Brief situation analysis fields are invalid.',
      );
    }
    return MorningBriefSituationAnalysis(
      body: ReportSyncRecordUtils.string(json, 'body'),
      recovery: ReportSyncRecordUtils.string(json, 'recovery'),
      condition: ReportSyncRecordUtils.string(json, 'condition'),
      work: ReportSyncRecordUtils.string(json, 'work'),
      carryover: ReportSyncRecordUtils.string(json, 'carryover'),
      overall: ReportSyncRecordUtils.string(json, 'overall'),
      bodyDisplay: _display(json, 'bodyDisplay'),
      recoveryDisplay: _display(json, 'recoveryDisplay'),
      conditionDisplay: _display(json, 'conditionDisplay'),
      workDisplay: _display(json, 'workDisplay'),
    );
  }

  static MorningBriefSectionDisplay? _display(
    Map<String, Object?> json,
    String field,
  ) {
    final value = json[field];
    if (value == null) return null;
    if (value is! Map) {
      throw FormatException('Morning Brief $field is invalid.');
    }
    return MorningBriefSectionDisplay.fromJson(
      Map<String, Object?>.from(value),
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

class MorningBriefRevision {
  static const fields = {'revision', 'record'};

  final int revision;
  final MorningBriefRecord record;

  MorningBriefRevision({required this.revision, required this.record}) {
    if (revision < 1 || record.recordVersion > 2) {
      throw const FormatException('Morning Brief revision is invalid.');
    }
  }

  Map<String, Object?> toJson() => {
    'revision': revision,
    'record': record.toRecord(),
  };

  factory MorningBriefRevision.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    final revision = json['revision'];
    final record = json['record'];
    if (revision is! int || record is! Map) {
      throw const FormatException('Morning Brief revision is invalid.');
    }
    return MorningBriefRevision(
      revision: revision,
      record: MorningBriefRecord.fromRecord(Map<String, Object?>.from(record)),
    );
  }
}

class MorningBriefRecord {
  static const legacyRecordVersion = 1;
  static const previousRecordVersion = 2;
  static const currentRecordVersion = 3;
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
  static const previousFields = {
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
  static const currentFields = {
    ...previousFields,
    'revision',
    'previousRevisions',
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
  final int revision;
  final List<MorningBriefRevision> previousRevisions;

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
       actions = List.unmodifiable(actions),
       revision = 1,
       previousRevisions = const [] {
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
  }) : recordVersion = previousRecordVersion,
       requestId = null,
       requestDigest = null,
       _legacySituationAnalysis = null,
       argoComment = null,
       _legacyStrategicResourceDecision = null,
       actions = List.unmodifiable(actions),
       revision = 1,
       previousRevisions = const [] {
    _validateCurrentIdentity();
    _validateTimestamps();
  }

  MorningBriefRecord.revisioned({
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
    required this.revision,
    required Iterable<MorningBriefRevision> previousRevisions,
  }) : recordVersion = currentRecordVersion,
       requestId = null,
       requestDigest = null,
       _legacySituationAnalysis = null,
       argoComment = null,
       _legacyStrategicResourceDecision = null,
       actions = List.unmodifiable(actions),
       previousRevisions = List.unmodifiable(previousRevisions) {
    _validateCurrentIdentity();
    if (revision < 1 ||
        this.previousRevisions.length != revision - 1 ||
        this.previousRevisions.indexed.any(
          (entry) =>
              entry.$2.revision != entry.$1 + 1 ||
              entry.$2.record.localDate != localDate,
        )) {
      throw const FormatException('Morning Brief revision history is invalid.');
    }
    _validateTimestamps();
  }

  void _validateCurrentIdentity() {
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

  bool get isCurrentFormat => recordVersion >= previousRecordVersion;

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

  Map<String, Object?> toRecord() => isCurrentFormat
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
          if (recordVersion >= currentRecordVersion) ...{
            'revision': revision,
            'previousRevisions': [
              for (final value in previousRevisions) value.toJson(),
            ],
          },
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
    if (version == previousRecordVersion) return _fromPreviousRecord(json);
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

  static MorningBriefRecord _fromPreviousRecord(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, previousFields);
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

  static MorningBriefRecord _fromCurrentRecord(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, currentFields);
    final previous = json['previousRevisions'];
    if (previous is! List || previous.any((value) => value is! Map)) {
      throw const FormatException('previousRevisions is invalid.');
    }
    final base = _fromPreviousRecord({
      for (final entry in json.entries)
        if (entry.key != 'revision' &&
            entry.key != 'previousRevisions' &&
            entry.key != 'recordVersion')
          entry.key: entry.value,
      'recordVersion': previousRecordVersion,
    });
    final revision = json['revision'];
    if (revision is! int) {
      throw const FormatException('revision is invalid.');
    }
    return MorningBriefRecord.revisioned(
      localDate: base.localDate,
      sourceType: base.sourceType,
      sourceOperationDate: base.sourceOperationDate,
      sourceRecordId: base.sourceRecordId,
      sourceDigest: base.sourceDigest,
      responseDigest: base.responseDigest,
      exchangeId: base.exchangeId,
      generatedAt: base.generatedAt,
      importedAt: base.importedAt,
      situationAnalysisV2: base.situationAnalysisV2,
      operatingPolicy: base.operatingPolicy,
      strategicResourceDecisionV2: base.strategicResourceDecisionV2,
      operationStatus: base.operationStatus,
      commanderIntent: base.commanderIntent,
      actions: base.actions,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      revision: revision,
      previousRevisions: [
        for (final value in previous)
          MorningBriefRevision.fromJson(
            Map<String, Object?>.from(value as Map),
          ),
      ],
    );
  }

  MorningBriefRecord asInitialRevision() {
    if (recordVersion != previousRecordVersion) return this;
    return MorningBriefRecord.revisioned(
      localDate: localDate,
      sourceType: sourceType,
      sourceOperationDate: sourceOperationDate,
      sourceRecordId: sourceRecordId,
      sourceDigest: sourceDigest,
      responseDigest: responseDigest,
      exchangeId: exchangeId,
      generatedAt: generatedAt,
      importedAt: importedAt,
      situationAnalysisV2: situationAnalysisV2,
      operatingPolicy: operatingPolicy,
      strategicResourceDecisionV2: strategicResourceDecisionV2,
      operationStatus: operationStatus,
      commanderIntent: commanderIntent,
      actions: actions,
      createdAt: createdAt,
      updatedAt: updatedAt,
      revision: 1,
      previousRevisions: const [],
    );
  }

  MorningBriefRecord reviseWith(
    MorningBriefRecord next, {
    required DateTime timestamp,
  }) {
    if (next.recordVersion != previousRecordVersion ||
        next.localDate != localDate) {
      throw const FormatException('Morning Brief revision input is invalid.');
    }
    final current = asInitialRevision();
    return MorningBriefRecord.revisioned(
      localDate: localDate,
      sourceType: next.sourceType,
      sourceOperationDate: next.sourceOperationDate,
      sourceRecordId: next.sourceRecordId,
      sourceDigest: next.sourceDigest,
      responseDigest: next.responseDigest,
      exchangeId: next.exchangeId,
      generatedAt: next.generatedAt,
      importedAt: next.importedAt,
      situationAnalysisV2: next.situationAnalysisV2,
      operatingPolicy: next.operatingPolicy,
      strategicResourceDecisionV2: next.strategicResourceDecisionV2,
      operationStatus: next.operationStatus,
      commanderIntent: next.commanderIntent,
      actions: next.actions,
      createdAt: current.createdAt,
      updatedAt: timestamp,
      revision: current.revision + 1,
      previousRevisions: [
        ...current.previousRevisions,
        MorningBriefRevision(
          revision: current.revision,
          record: current._snapshotRecord(),
        ),
      ],
    );
  }

  MorningBriefRecord _snapshotRecord() => recordVersion == legacyRecordVersion
      ? this
      : MorningBriefRecord.v2(
          localDate: localDate,
          sourceType: sourceType,
          sourceOperationDate: sourceOperationDate,
          sourceRecordId: sourceRecordId,
          sourceDigest: sourceDigest,
          responseDigest: responseDigest,
          exchangeId: exchangeId,
          generatedAt: generatedAt,
          importedAt: importedAt,
          situationAnalysisV2: situationAnalysisV2,
          operatingPolicy: operatingPolicy,
          strategicResourceDecisionV2: strategicResourceDecisionV2,
          operationStatus: operationStatus,
          commanderIntent: commanderIntent,
          actions: actions,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

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
