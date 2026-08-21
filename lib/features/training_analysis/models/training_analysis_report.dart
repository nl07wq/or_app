import '../../report_sync/models/report_sync_record_utils.dart';

class TrainingExerciseAnalysis {
  static const fields = {
    'exerciseIdentity',
    'exerciseName',
    'assessment',
    'previousComparison',
    'progress',
    'nextProposal',
  };

  const TrainingExerciseAnalysis({
    required this.exerciseIdentity,
    required this.exerciseName,
    required this.assessment,
    required this.previousComparison,
    required this.progress,
    required this.nextProposal,
  });

  final String exerciseIdentity;
  final String exerciseName;
  final String assessment;
  final String previousComparison;
  final String progress;
  final String nextProposal;

  Map<String, Object?> toJson() => {
    'exerciseIdentity': exerciseIdentity,
    'exerciseName': exerciseName,
    'assessment': assessment,
    'previousComparison': previousComparison,
    'progress': progress,
    'nextProposal': nextProposal,
  };

  factory TrainingExerciseAnalysis.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    return TrainingExerciseAnalysis(
      exerciseIdentity: ReportSyncRecordUtils.string(json, 'exerciseIdentity'),
      exerciseName: ReportSyncRecordUtils.string(json, 'exerciseName'),
      assessment: ReportSyncRecordUtils.string(json, 'assessment'),
      previousComparison: ReportSyncRecordUtils.string(
        json,
        'previousComparison',
      ),
      progress: ReportSyncRecordUtils.string(json, 'progress'),
      nextProposal: ReportSyncRecordUtils.string(json, 'nextProposal'),
    );
  }
}

class TrainingAnalysis {
  static const fields = {
    'sessionSummary',
    'performanceAnalysis',
    'previousComparison',
    'progressAnalysis',
    'recoveryFrequencyComment',
    'nextSessionProposal',
    'riskAttentionNotes',
    'exerciseAnalyses',
  };

  TrainingAnalysis({
    required this.sessionSummary,
    required this.performanceAnalysis,
    required this.previousComparison,
    required this.progressAnalysis,
    required this.recoveryFrequencyComment,
    required this.nextSessionProposal,
    required this.riskAttentionNotes,
    required Iterable<TrainingExerciseAnalysis> exerciseAnalyses,
  }) : exerciseAnalyses = List.unmodifiable(exerciseAnalyses);

  final String sessionSummary;
  final String performanceAnalysis;
  final String previousComparison;
  final String progressAnalysis;
  final String recoveryFrequencyComment;
  final String nextSessionProposal;
  final String riskAttentionNotes;
  final List<TrainingExerciseAnalysis> exerciseAnalyses;

  Map<String, Object?> toJson() => {
    'sessionSummary': sessionSummary,
    'performanceAnalysis': performanceAnalysis,
    'previousComparison': previousComparison,
    'progressAnalysis': progressAnalysis,
    'recoveryFrequencyComment': recoveryFrequencyComment,
    'nextSessionProposal': nextSessionProposal,
    'riskAttentionNotes': riskAttentionNotes,
    'exerciseAnalyses': [for (final value in exerciseAnalyses) value.toJson()],
  };

  factory TrainingAnalysis.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    final raw = json['exerciseAnalyses'];
    if (raw is! List || raw.any((value) => value is! Map)) {
      throw const FormatException('exerciseAnalyses is invalid.');
    }
    return TrainingAnalysis(
      sessionSummary: ReportSyncRecordUtils.string(json, 'sessionSummary'),
      performanceAnalysis: ReportSyncRecordUtils.string(
        json,
        'performanceAnalysis',
      ),
      previousComparison: ReportSyncRecordUtils.string(
        json,
        'previousComparison',
      ),
      progressAnalysis: ReportSyncRecordUtils.string(json, 'progressAnalysis'),
      recoveryFrequencyComment: ReportSyncRecordUtils.string(
        json,
        'recoveryFrequencyComment',
      ),
      nextSessionProposal: ReportSyncRecordUtils.string(
        json,
        'nextSessionProposal',
      ),
      riskAttentionNotes: ReportSyncRecordUtils.string(
        json,
        'riskAttentionNotes',
      ),
      exerciseAnalyses: [
        for (final value in raw)
          TrainingExerciseAnalysis.fromJson(
            Map<String, Object?>.from(value as Map),
          ),
      ],
    );
  }
}

class TrainingAnalysisRevision {
  static const fields = {
    'revision',
    'sourceDigest',
    'responseDigest',
    'exchangeId',
    'importedAt',
    'analysis',
  };

  const TrainingAnalysisRevision({
    required this.revision,
    required this.sourceDigest,
    required this.responseDigest,
    required this.exchangeId,
    required this.importedAt,
    required this.analysis,
  });

  final int revision;
  final String sourceDigest;
  final String responseDigest;
  final String exchangeId;
  final DateTime importedAt;
  final TrainingAnalysis analysis;

  Map<String, Object?> toJson() => {
    'revision': revision,
    'sourceDigest': sourceDigest,
    'responseDigest': responseDigest,
    'exchangeId': exchangeId,
    'importedAt': importedAt.toUtc().toIso8601String(),
    'analysis': analysis.toJson(),
  };

  factory TrainingAnalysisRevision.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    return TrainingAnalysisRevision(
      revision: _positiveInt(json['revision'], 'revision'),
      sourceDigest: ReportSyncRecordUtils.digest(json, 'sourceDigest'),
      responseDigest: ReportSyncRecordUtils.digest(json, 'responseDigest'),
      exchangeId: ReportSyncRecordUtils.string(json, 'exchangeId'),
      importedAt: ReportSyncRecordUtils.date(json, 'importedAt'),
      analysis: TrainingAnalysis.fromJson(
        Map<String, Object?>.from(json['analysis'] as Map),
      ),
    );
  }
}

class TrainingAnalysisReport {
  static const currentRecordVersion = 1;
  static const fields = {
    'targetRecordId',
    'recordVersion',
    'operationDate',
    'revision',
    'sourceDigest',
    'responseDigest',
    'exchangeId',
    'importedAt',
    'updatedAt',
    'analysis',
    'previousRevisions',
  };

  TrainingAnalysisReport({
    required this.targetRecordId,
    this.recordVersion = currentRecordVersion,
    required this.operationDate,
    required this.revision,
    required this.sourceDigest,
    required this.responseDigest,
    required this.exchangeId,
    required this.importedAt,
    required this.updatedAt,
    required this.analysis,
    required Iterable<TrainingAnalysisRevision> previousRevisions,
  }) : previousRevisions = List.unmodifiable(previousRevisions) {
    if (recordVersion != currentRecordVersion ||
        revision < 1 ||
        this.previousRevisions.length != revision - 1 ||
        this.previousRevisions.indexed.any(
          (entry) => entry.$2.revision != entry.$1 + 1,
        )) {
      throw const FormatException('Training Analysis revision is invalid.');
    }
  }

  final String targetRecordId;
  final int recordVersion;
  final String operationDate;
  final int revision;
  final String sourceDigest;
  final String responseDigest;
  final String exchangeId;
  final DateTime importedAt;
  final DateTime updatedAt;
  final TrainingAnalysis analysis;
  final List<TrainingAnalysisRevision> previousRevisions;

  factory TrainingAnalysisReport.initial({
    required String targetRecordId,
    required String operationDate,
    required String sourceDigest,
    required String responseDigest,
    required String exchangeId,
    required DateTime timestamp,
    required TrainingAnalysis analysis,
  }) => TrainingAnalysisReport(
    targetRecordId: targetRecordId,
    operationDate: operationDate,
    revision: 1,
    sourceDigest: sourceDigest,
    responseDigest: responseDigest,
    exchangeId: exchangeId,
    importedAt: timestamp,
    updatedAt: timestamp,
    analysis: analysis,
    previousRevisions: const [],
  );

  TrainingAnalysisReport revise({
    required String sourceDigest,
    required String responseDigest,
    required String exchangeId,
    required DateTime timestamp,
    required TrainingAnalysis analysis,
  }) => TrainingAnalysisReport(
    targetRecordId: targetRecordId,
    operationDate: operationDate,
    revision: revision + 1,
    sourceDigest: sourceDigest,
    responseDigest: responseDigest,
    exchangeId: exchangeId,
    importedAt: importedAt,
    updatedAt: timestamp,
    analysis: analysis,
    previousRevisions: [
      ...previousRevisions,
      TrainingAnalysisRevision(
        revision: revision,
        sourceDigest: this.sourceDigest,
        responseDigest: this.responseDigest,
        exchangeId: this.exchangeId,
        importedAt: updatedAt,
        analysis: this.analysis,
      ),
    ],
  );

  Map<String, Object?> toRecord() => {
    'targetRecordId': targetRecordId,
    'recordVersion': recordVersion,
    'operationDate': operationDate,
    'revision': revision,
    'sourceDigest': sourceDigest,
    'responseDigest': responseDigest,
    'exchangeId': exchangeId,
    'importedAt': importedAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'analysis': analysis.toJson(),
    'previousRevisions': [
      for (final value in previousRevisions) value.toJson(),
    ],
  };

  factory TrainingAnalysisReport.fromRecord(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    final rawPrevious = json['previousRevisions'];
    if (rawPrevious is! List || rawPrevious.any((value) => value is! Map)) {
      throw const FormatException('previousRevisions is invalid.');
    }
    return TrainingAnalysisReport(
      targetRecordId: ReportSyncRecordUtils.string(json, 'targetRecordId'),
      recordVersion: _positiveInt(json['recordVersion'], 'recordVersion'),
      operationDate: ReportSyncRecordUtils.localDate(json, 'operationDate'),
      revision: _positiveInt(json['revision'], 'revision'),
      sourceDigest: ReportSyncRecordUtils.digest(json, 'sourceDigest'),
      responseDigest: ReportSyncRecordUtils.digest(json, 'responseDigest'),
      exchangeId: ReportSyncRecordUtils.string(json, 'exchangeId'),
      importedAt: ReportSyncRecordUtils.date(json, 'importedAt'),
      updatedAt: ReportSyncRecordUtils.date(json, 'updatedAt'),
      analysis: TrainingAnalysis.fromJson(
        Map<String, Object?>.from(json['analysis'] as Map),
      ),
      previousRevisions: [
        for (final value in rawPrevious)
          TrainingAnalysisRevision.fromJson(
            Map<String, Object?>.from(value as Map),
          ),
      ],
    );
  }
}

int _positiveInt(Object? value, String key) {
  if (value is! int || value < 1) throw FormatException('$key is invalid.');
  return value;
}
