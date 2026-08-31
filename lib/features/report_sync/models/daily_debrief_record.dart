import 'report_sync_record_utils.dart';

enum DailyDebriefLifecycleStatus { active, stale, invalidated }

enum DailyDebriefCommanderIntentOutcome {
  achieved,
  partiallyAchieved,
  notAchieved,
  notAssessable,
}

class DailyDebriefDailyAggregateReference {
  static const fields = {'operationDate', 'sourceType', 'recordDigest'};

  final String operationDate;
  final String sourceType;
  final String recordDigest;

  const DailyDebriefDailyAggregateReference({
    required this.operationDate,
    required this.sourceType,
    required this.recordDigest,
  });

  Map<String, Object?> toJson() => {
    'operationDate': operationDate,
    'sourceType': sourceType,
    'recordDigest': recordDigest,
  };

  factory DailyDebriefDailyAggregateReference.fromJson(
    Map<String, Object?> json,
  ) {
    ReportSyncRecordUtils.exactFields(json, fields);
    final sourceType = ReportSyncRecordUtils.string(json, 'sourceType');
    if (sourceType != 'records') {
      throw const FormatException(
        'Daily Aggregate sourceType must be records.',
      );
    }
    return DailyDebriefDailyAggregateReference(
      operationDate: ReportSyncRecordUtils.localDate(json, 'operationDate'),
      sourceType: sourceType,
      recordDigest: ReportSyncRecordUtils.digest(json, 'recordDigest'),
    );
  }
}

class DailyDebriefConfirmationReference {
  static const fields = {
    'recordId',
    'recordVersion',
    'revision',
    'snapshotDigest',
    'recordDigest',
  };

  final String recordId;
  final int recordVersion;
  final int revision;
  final String snapshotDigest;
  final String recordDigest;

  const DailyDebriefConfirmationReference({
    required this.recordId,
    required this.recordVersion,
    required this.revision,
    required this.snapshotDigest,
    required this.recordDigest,
  });

  Map<String, Object?> toJson() => {
    'recordId': recordId,
    'recordVersion': recordVersion,
    'revision': revision,
    'snapshotDigest': snapshotDigest,
    'recordDigest': recordDigest,
  };

  factory DailyDebriefConfirmationReference.fromJson(
    Map<String, Object?> json,
  ) {
    ReportSyncRecordUtils.exactFields(json, fields);
    final version = _positiveInt(json, 'recordVersion');
    final revision = _positiveInt(json, 'revision');
    final snapshotDigest = ReportSyncRecordUtils.string(json, 'snapshotDigest');
    if (!RegExp(r'^[0-9a-f]{8}$').hasMatch(snapshotDigest)) {
      throw const FormatException('snapshotDigest is invalid.');
    }
    return DailyDebriefConfirmationReference(
      recordId: ReportSyncRecordUtils.string(json, 'recordId'),
      recordVersion: version,
      revision: revision,
      snapshotDigest: snapshotDigest,
      recordDigest: ReportSyncRecordUtils.digest(json, 'recordDigest'),
    );
  }
}

class DailyDebriefMorningBriefReference {
  static const fields = {
    'localDate',
    'recordVersion',
    'responseDigest',
    'recordDigest',
  };

  final String localDate;
  final int recordVersion;
  final String responseDigest;
  final String recordDigest;

  const DailyDebriefMorningBriefReference({
    required this.localDate,
    required this.recordVersion,
    required this.responseDigest,
    required this.recordDigest,
  });

  Map<String, Object?> toJson() => {
    'localDate': localDate,
    'recordVersion': recordVersion,
    'responseDigest': responseDigest,
    'recordDigest': recordDigest,
  };

  factory DailyDebriefMorningBriefReference.fromJson(
    Map<String, Object?> json,
  ) {
    ReportSyncRecordUtils.exactFields(json, fields);
    return DailyDebriefMorningBriefReference(
      localDate: ReportSyncRecordUtils.localDate(json, 'localDate'),
      recordVersion: _positiveInt(json, 'recordVersion'),
      responseDigest: ReportSyncRecordUtils.digest(json, 'responseDigest'),
      recordDigest: ReportSyncRecordUtils.digest(json, 'recordDigest'),
    );
  }
}

class DailyDebriefSources {
  static const fields = {'dailyAggregate', 'confirmation', 'morningBrief'};

  final DailyDebriefDailyAggregateReference dailyAggregate;
  final DailyDebriefConfirmationReference confirmation;
  final DailyDebriefMorningBriefReference? morningBrief;

  const DailyDebriefSources({
    required this.dailyAggregate,
    required this.confirmation,
    required this.morningBrief,
  });

  Map<String, Object?> toJson() => {
    'dailyAggregate': dailyAggregate.toJson(),
    'confirmation': confirmation.toJson(),
    'morningBrief': morningBrief?.toJson(),
  };

  factory DailyDebriefSources.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    final aggregate = _object(json, 'dailyAggregate');
    final confirmation = _object(json, 'confirmation');
    final morningBrief = json['morningBrief'];
    if (morningBrief != null && morningBrief is! Map) {
      throw const FormatException('morningBrief is invalid.');
    }
    final value = DailyDebriefSources(
      dailyAggregate: DailyDebriefDailyAggregateReference.fromJson(aggregate),
      confirmation: DailyDebriefConfirmationReference.fromJson(confirmation),
      morningBrief: morningBrief == null
          ? null
          : DailyDebriefMorningBriefReference.fromJson(
              Map<String, Object?>.from(morningBrief as Map),
            ),
    );
    if (value.confirmation.recordId !=
            'confirmation:${value.dailyAggregate.operationDate}' ||
        (value.morningBrief != null &&
            value.morningBrief!.localDate !=
                value.dailyAggregate.operationDate)) {
      throw const FormatException('Daily Debrief source identity is invalid.');
    }
    return value;
  }
}

class DailyDebriefCommanderIntentEvaluation {
  static const fields = {'outcome', 'rationale', 'evidence'};

  final DailyDebriefCommanderIntentOutcome outcome;
  final String rationale;
  final List<String> evidence;

  DailyDebriefCommanderIntentEvaluation({
    required this.outcome,
    required String rationale,
    required Iterable<String> evidence,
  }) : rationale = _nonEmpty(rationale, 'rationale'),
       evidence = _stringList(evidence, 'evidence');

  Map<String, Object?> toJson() => {
    'outcome': outcome.name,
    'rationale': rationale,
    'evidence': evidence,
  };

  factory DailyDebriefCommanderIntentEvaluation.fromJson(
    Map<String, Object?> json,
  ) {
    ReportSyncRecordUtils.exactFields(json, fields);
    final raw = ReportSyncRecordUtils.string(json, 'outcome');
    final outcome = DailyDebriefCommanderIntentOutcome.values.where(
      (value) => value.name == raw,
    );
    if (outcome.isEmpty) {
      throw const FormatException('Unknown commander intent outcome.');
    }
    return DailyDebriefCommanderIntentEvaluation(
      outcome: outcome.single,
      rationale: ReportSyncRecordUtils.string(json, 'rationale'),
      evidence: _strings(json, 'evidence'),
    );
  }
}

class DailyDebriefDomainEvaluations {
  static const fields = {
    'body',
    'recovery',
    'condition',
    'work',
    'nutrition',
    'hydration',
    'activity',
    'training',
  };

  final String? body;
  final String? recovery;
  final String? condition;
  final String? work;
  final String? nutrition;
  final String? hydration;
  final String? activity;
  final String? training;

  DailyDebriefDomainEvaluations({
    required String? body,
    required String? recovery,
    required String? condition,
    required String? work,
    required String? nutrition,
    required String? hydration,
    required String? activity,
    required String? training,
  }) : body = _nullableNonEmpty(body, 'body'),
       recovery = _nullableNonEmpty(recovery, 'recovery'),
       condition = _nullableNonEmpty(condition, 'condition'),
       work = _nullableNonEmpty(work, 'work'),
       nutrition = _nullableNonEmpty(nutrition, 'nutrition'),
       hydration = _nullableNonEmpty(hydration, 'hydration'),
       activity = _nullableNonEmpty(activity, 'activity'),
       training = _nullableNonEmpty(training, 'training');

  Map<String, Object?> toJson() => {
    'body': body,
    'recovery': recovery,
    'condition': condition,
    'work': work,
    'nutrition': nutrition,
    'hydration': hydration,
    'activity': activity,
    'training': training,
  };

  factory DailyDebriefDomainEvaluations.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    return DailyDebriefDomainEvaluations(
      body: _nullableString(json, 'body'),
      recovery: _nullableString(json, 'recovery'),
      condition: _nullableString(json, 'condition'),
      work: _nullableString(json, 'work'),
      nutrition: _nullableString(json, 'nutrition'),
      hydration: _nullableString(json, 'hydration'),
      activity: _nullableString(json, 'activity'),
      training: _nullableString(json, 'training'),
    );
  }
}

class DailyDebriefCrossAnalysis {
  static const fields = {
    'keyFactors',
    'interactions',
    'constraints',
    'resources',
  };

  final List<String> keyFactors;
  final List<String> interactions;
  final List<String> constraints;
  final List<String> resources;

  DailyDebriefCrossAnalysis({
    required Iterable<String> keyFactors,
    required Iterable<String> interactions,
    required Iterable<String> constraints,
    required Iterable<String> resources,
  }) : keyFactors = _stringList(keyFactors, 'keyFactors'),
       interactions = _stringList(interactions, 'interactions'),
       constraints = _stringList(constraints, 'constraints'),
       resources = _stringList(resources, 'resources');

  Map<String, Object?> toJson() => {
    'keyFactors': keyFactors,
    'interactions': interactions,
    'constraints': constraints,
    'resources': resources,
  };

  factory DailyDebriefCrossAnalysis.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    return DailyDebriefCrossAnalysis(
      keyFactors: _strings(json, 'keyFactors'),
      interactions: _strings(json, 'interactions'),
      constraints: _strings(json, 'constraints'),
      resources: _strings(json, 'resources'),
    );
  }
}

class DailyDebriefExecutionEvaluation {
  static const fields = {'successes', 'adjustments'};

  final List<String> successes;
  final List<String> adjustments;

  DailyDebriefExecutionEvaluation({
    required Iterable<String> successes,
    required Iterable<String> adjustments,
  }) : successes = _stringList(successes, 'successes'),
       adjustments = _stringList(adjustments, 'adjustments');

  Map<String, Object?> toJson() => {
    'successes': successes,
    'adjustments': adjustments,
  };

  factory DailyDebriefExecutionEvaluation.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    return DailyDebriefExecutionEvaluation(
      successes: _strings(json, 'successes'),
      adjustments: _strings(json, 'adjustments'),
    );
  }
}

class DailyDebriefNextDayHandoff {
  static const fields = {'watchPoints'};

  final List<String> watchPoints;

  DailyDebriefNextDayHandoff({required Iterable<String> watchPoints})
    : watchPoints = _stringList(watchPoints, 'watchPoints');

  Map<String, Object?> toJson() => {'watchPoints': watchPoints};

  factory DailyDebriefNextDayHandoff.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    return DailyDebriefNextDayHandoff(
      watchPoints: _strings(json, 'watchPoints'),
    );
  }
}

class DailyDebriefAnalysis {
  static const fields = {
    'commanderIntentEvaluation',
    'domainEvaluations',
    'crossAnalysis',
    'executionEvaluation',
    'nextDayHandoff',
  };

  final DailyDebriefCommanderIntentEvaluation? commanderIntentEvaluation;
  final DailyDebriefDomainEvaluations domainEvaluations;
  final DailyDebriefCrossAnalysis crossAnalysis;
  final DailyDebriefExecutionEvaluation executionEvaluation;
  final DailyDebriefNextDayHandoff nextDayHandoff;

  const DailyDebriefAnalysis({
    required this.commanderIntentEvaluation,
    required this.domainEvaluations,
    required this.crossAnalysis,
    required this.executionEvaluation,
    required this.nextDayHandoff,
  });

  Map<String, Object?> toJson() => {
    'commanderIntentEvaluation': commanderIntentEvaluation?.toJson(),
    'domainEvaluations': domainEvaluations.toJson(),
    'crossAnalysis': crossAnalysis.toJson(),
    'executionEvaluation': executionEvaluation.toJson(),
    'nextDayHandoff': nextDayHandoff.toJson(),
  };

  factory DailyDebriefAnalysis.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    final commanderIntent = json['commanderIntentEvaluation'];
    if (commanderIntent != null && commanderIntent is! Map) {
      throw const FormatException('commanderIntentEvaluation is invalid.');
    }
    return DailyDebriefAnalysis(
      commanderIntentEvaluation: commanderIntent == null
          ? null
          : DailyDebriefCommanderIntentEvaluation.fromJson(
              Map<String, Object?>.from(commanderIntent as Map),
            ),
      domainEvaluations: DailyDebriefDomainEvaluations.fromJson(
        _object(json, 'domainEvaluations'),
      ),
      crossAnalysis: DailyDebriefCrossAnalysis.fromJson(
        _object(json, 'crossAnalysis'),
      ),
      executionEvaluation: DailyDebriefExecutionEvaluation.fromJson(
        _object(json, 'executionEvaluation'),
      ),
      nextDayHandoff: DailyDebriefNextDayHandoff.fromJson(
        _object(json, 'nextDayHandoff'),
      ),
    );
  }
}

class DailyDebriefRevision {
  static const fields = {
    'revision',
    'sources',
    'analysis',
    'responseDigest',
    'createdAt',
  };

  final int revision;
  final DailyDebriefSources sources;
  final DailyDebriefAnalysis analysis;
  final String responseDigest;
  final DateTime createdAt;

  DailyDebriefRevision({
    required this.revision,
    required this.sources,
    required this.analysis,
    required this.responseDigest,
    required DateTime createdAt,
  }) : createdAt = createdAt.toUtc() {
    if (revision < 1) throw const FormatException('revision is invalid.');
    if (!ReportSyncRecordUtils.isDigest(responseDigest)) {
      throw const FormatException('responseDigest is invalid.');
    }
  }

  Map<String, Object?> toJson() => {
    'revision': revision,
    'sources': sources.toJson(),
    'analysis': analysis.toJson(),
    'responseDigest': responseDigest,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DailyDebriefRevision.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    return DailyDebriefRevision(
      revision: _positiveInt(json, 'revision'),
      sources: DailyDebriefSources.fromJson(_object(json, 'sources')),
      analysis: DailyDebriefAnalysis.fromJson(_object(json, 'analysis')),
      responseDigest: ReportSyncRecordUtils.digest(json, 'responseDigest'),
      createdAt: ReportSyncRecordUtils.date(json, 'createdAt'),
    );
  }
}

class DailyDebriefRecord {
  static const currentRecordVersion = 1;
  static const fields = {
    'localDate',
    'recordVersion',
    'revision',
    'sources',
    'analysis',
    'responseDigest',
    'createdAt',
    'updatedAt',
    'previousRevisions',
  };
  static const archivedFields = {...fields, 'archivedRevisions'};

  final String localDate;
  final int recordVersion;
  final int revision;
  final DailyDebriefSources sources;
  final DailyDebriefAnalysis analysis;
  final String responseDigest;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DailyDebriefRevision> previousRevisions;
  final List<Map<String, Object?>> archivedRevisions;

  DailyDebriefRecord({
    required this.localDate,
    this.recordVersion = currentRecordVersion,
    required this.revision,
    required this.sources,
    required this.analysis,
    required this.responseDigest,
    required DateTime createdAt,
    required DateTime updatedAt,
    required Iterable<DailyDebriefRevision> previousRevisions,
    Iterable<Map<String, Object?>> archivedRevisions = const [],
  }) : createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc(),
       previousRevisions = List.unmodifiable(previousRevisions),
       archivedRevisions = List.unmodifiable(
         archivedRevisions.map(Map<String, Object?>.unmodifiable),
       ) {
    if (recordVersion != currentRecordVersion ||
        revision < 1 ||
        localDate != sources.dailyAggregate.operationDate ||
        updatedAt.isBefore(this.createdAt) ||
        !ReportSyncRecordUtils.isDigest(responseDigest) ||
        this.archivedRevisions.length + this.previousRevisions.length !=
            revision - 1 ||
        this.archivedRevisions.indexed.any(
          (entry) =>
              entry.$2['revision'] != entry.$1 + 1 ||
              !ReportSyncRecordUtils.isArchiveBodyDigest(
                entry.$2['bodyDigest'],
              ),
        ) ||
        this.previousRevisions.indexed.any(
          (entry) =>
              entry.$2.revision != this.archivedRevisions.length + entry.$1 + 1,
        )) {
      throw const FormatException('Daily Debrief record is invalid.');
    }
  }

  factory DailyDebriefRecord.initial({
    required String localDate,
    required DailyDebriefSources sources,
    required DailyDebriefAnalysis analysis,
    required String responseDigest,
    required DateTime timestamp,
  }) => DailyDebriefRecord(
    localDate: localDate,
    revision: 1,
    sources: sources,
    analysis: analysis,
    responseDigest: responseDigest,
    createdAt: timestamp,
    updatedAt: timestamp,
    previousRevisions: const [],
    archivedRevisions: const [],
  );

  DailyDebriefRecord revise({
    required DailyDebriefSources sources,
    required DailyDebriefAnalysis analysis,
    required String responseDigest,
    required DateTime timestamp,
  }) => DailyDebriefRecord(
    localDate: localDate,
    revision: revision + 1,
    sources: sources,
    analysis: analysis,
    responseDigest: responseDigest,
    createdAt: createdAt,
    updatedAt: timestamp,
    previousRevisions: [
      ...previousRevisions,
      DailyDebriefRevision(
        revision: revision,
        sources: this.sources,
        analysis: this.analysis,
        responseDigest: this.responseDigest,
        createdAt: updatedAt,
      ),
    ],
    archivedRevisions: archivedRevisions,
  );

  Map<String, Object?> toRecord() => {
    'localDate': localDate,
    'recordVersion': recordVersion,
    'revision': revision,
    'sources': sources.toJson(),
    'analysis': analysis.toJson(),
    'responseDigest': responseDigest,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'previousRevisions': [
      for (final value in previousRevisions) value.toJson(),
    ],
    if (archivedRevisions.isNotEmpty) 'archivedRevisions': archivedRevisions,
  };

  factory DailyDebriefRecord.fromRecord(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(
      json,
      json.containsKey('archivedRevisions') ? archivedFields : fields,
    );
    final values = json['previousRevisions'];
    if (values is! List || values.any((value) => value is! Map)) {
      throw const FormatException('previousRevisions is invalid.');
    }
    final archived = json['archivedRevisions'] ?? const <Object?>[];
    if (archived is! List || archived.any((value) => value is! Map)) {
      throw const FormatException('archivedRevisions is invalid.');
    }
    return DailyDebriefRecord(
      localDate: ReportSyncRecordUtils.localDate(json, 'localDate'),
      recordVersion: _positiveInt(json, 'recordVersion'),
      revision: _positiveInt(json, 'revision'),
      sources: DailyDebriefSources.fromJson(_object(json, 'sources')),
      analysis: DailyDebriefAnalysis.fromJson(_object(json, 'analysis')),
      responseDigest: ReportSyncRecordUtils.digest(json, 'responseDigest'),
      createdAt: ReportSyncRecordUtils.date(json, 'createdAt'),
      updatedAt: ReportSyncRecordUtils.date(json, 'updatedAt'),
      previousRevisions: [
        for (final value in values)
          DailyDebriefRevision.fromJson(
            Map<String, Object?>.from(value as Map),
          ),
      ],
      archivedRevisions: [
        for (final value in archived) Map<String, Object?>.from(value as Map),
      ],
    );
  }
}

Map<String, Object?> _object(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! Map) throw FormatException('$key is invalid.');
  return Map<String, Object?>.from(value);
}

int _positiveInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int || value < 1) throw FormatException('$key is invalid.');
  return value;
}

String? _nullableString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key is invalid.');
  return _nonEmpty(value, key);
}

String _nonEmpty(String value, String key) {
  if (value.trim().isEmpty) throw FormatException('$key is invalid.');
  return value;
}

List<String> _strings(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('$key is invalid.');
  }
  return _stringList(value.cast<String>(), key);
}

List<String> _stringList(Iterable<String> values, String key) {
  final result = values.toList(growable: false);
  if (result.any((value) => value.trim().isEmpty)) {
    throw FormatException('$key is invalid.');
  }
  return List.unmodifiable(result);
}

String? _nullableNonEmpty(String? value, String key) =>
    value == null ? null : _nonEmpty(value, key);
