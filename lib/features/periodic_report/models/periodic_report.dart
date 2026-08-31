import '../../../core/models/operation_calendar_period.dart';
import '../../report_sync/models/report_sync_record_utils.dart';

enum PeriodicReportType {
  weekly('weekly'),
  monthly('monthly'),
  yearly('yearly');

  const PeriodicReportType(this.stableId);
  final String stableId;

  static PeriodicReportType parse(Object? value) => values.firstWhere(
    (item) => item.stableId == value,
    orElse: () => throw const FormatException('Invalid periodic report type.'),
  );
}

class PeriodicMetricFact {
  static const fields = {
    'sampleCount',
    'total',
    'average',
    'minimum',
    'maximum',
    'start',
    'end',
    'change',
  };

  const PeriodicMetricFact({
    required this.sampleCount,
    this.total,
    this.average,
    this.minimum,
    this.maximum,
    this.start,
    this.end,
    this.change,
  });

  final int sampleCount;
  final double? total;
  final double? average;
  final double? minimum;
  final double? maximum;
  final double? start;
  final double? end;
  final double? change;

  Map<String, Object?> toJson() => {
    'sampleCount': sampleCount,
    'total': total,
    'average': average,
    'minimum': minimum,
    'maximum': maximum,
    'start': start,
    'end': end,
    'change': change,
  };

  factory PeriodicMetricFact.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    final count = json['sampleCount'];
    if (count is! int || count < 0) {
      throw const FormatException('Invalid periodic metric sample count.');
    }
    return PeriodicMetricFact(
      sampleCount: count,
      total: _number(json['total']),
      average: _number(json['average']),
      minimum: _number(json['minimum']),
      maximum: _number(json['maximum']),
      start: _number(json['start']),
      end: _number(json['end']),
      change: _number(json['change']),
    );
  }
}

class PeriodicMetricComparison {
  static const fields = {
    'totalDelta',
    'averageDelta',
    'startDelta',
    'endDelta',
    'changeDelta',
  };

  const PeriodicMetricComparison({
    this.totalDelta,
    this.averageDelta,
    this.startDelta,
    this.endDelta,
    this.changeDelta,
  });

  final double? totalDelta;
  final double? averageDelta;
  final double? startDelta;
  final double? endDelta;
  final double? changeDelta;

  bool get available =>
      totalDelta != null ||
      averageDelta != null ||
      startDelta != null ||
      endDelta != null ||
      changeDelta != null;

  Map<String, Object?> toJson() => {
    'totalDelta': totalDelta,
    'averageDelta': averageDelta,
    'startDelta': startDelta,
    'endDelta': endDelta,
    'changeDelta': changeDelta,
  };

  factory PeriodicMetricComparison.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    return PeriodicMetricComparison(
      totalDelta: _number(json['totalDelta']),
      averageDelta: _number(json['averageDelta']),
      startDelta: _number(json['startDelta']),
      endDelta: _number(json['endDelta']),
      changeDelta: _number(json['changeDelta']),
    );
  }
}

class PeriodicReportFacts {
  static const fields = {
    'reportType',
    'periodId',
    'startDate',
    'endDate',
    'expectedDailyCount',
    'availableDailyCount',
    'missingDailyDates',
    'sourceMonthlyFactIds',
    'missingMonthlyFactIds',
    'metrics',
    'previousPeriodComparisons',
    'operationStatusCounts',
    'trainingSessionCount',
    'trainingDays',
    'exercisesPerformed',
    'theoreticalWeightChangeKg',
    'actualWeightChangeKg',
  };

  PeriodicReportFacts({
    required this.reportType,
    required this.periodId,
    required this.startDate,
    required this.endDate,
    required this.expectedDailyCount,
    required this.availableDailyCount,
    required Iterable<String> missingDailyDates,
    required Iterable<String> sourceMonthlyFactIds,
    required Iterable<String> missingMonthlyFactIds,
    required Map<String, PeriodicMetricFact> metrics,
    required Map<String, PeriodicMetricComparison> previousPeriodComparisons,
    required Map<String, int> operationStatusCounts,
    required this.trainingSessionCount,
    required this.trainingDays,
    required Iterable<String> exercisesPerformed,
    required this.theoreticalWeightChangeKg,
    required this.actualWeightChangeKg,
  }) : missingDailyDates = List.unmodifiable(missingDailyDates),
       sourceMonthlyFactIds = List.unmodifiable(sourceMonthlyFactIds),
       missingMonthlyFactIds = List.unmodifiable(missingMonthlyFactIds),
       metrics = Map.unmodifiable(metrics),
       previousPeriodComparisons = Map.unmodifiable(previousPeriodComparisons),
       operationStatusCounts = Map.unmodifiable(operationStatusCounts),
       exercisesPerformed = List.unmodifiable(exercisesPerformed) {
    final start = DateTime.parse(startDate);
    final expectedPeriod = switch (reportType) {
      PeriodicReportType.weekly => OperationCalendarPeriod.week(start),
      PeriodicReportType.monthly => OperationCalendarPeriod.month(start),
      PeriodicReportType.yearly => OperationCalendarPeriod.year(start),
    };
    if (expectedDailyCount < 0 ||
        availableDailyCount < 0 ||
        availableDailyCount > expectedDailyCount ||
        trainingSessionCount < 0 ||
        trainingDays < 0 ||
        periodId != expectedPeriod.id ||
        startDate != _date(expectedPeriod.start) ||
        endDate != _date(expectedPeriod.end) ||
        expectedDailyCount != expectedPeriod.expectedDayCount) {
      throw const FormatException('Periodic report facts are invalid.');
    }
  }

  final PeriodicReportType reportType;
  final String periodId;
  final String startDate;
  final String endDate;
  final int expectedDailyCount;
  final int availableDailyCount;
  final List<String> missingDailyDates;
  final List<String> sourceMonthlyFactIds;
  final List<String> missingMonthlyFactIds;
  final Map<String, PeriodicMetricFact> metrics;
  final Map<String, PeriodicMetricComparison> previousPeriodComparisons;
  final Map<String, int> operationStatusCounts;
  final int trainingSessionCount;
  final int trainingDays;
  final List<String> exercisesPerformed;
  final double? theoreticalWeightChangeKg;
  final double? actualWeightChangeKg;

  Map<String, Object?> toJson() => {
    'reportType': reportType.stableId,
    'periodId': periodId,
    'startDate': startDate,
    'endDate': endDate,
    'expectedDailyCount': expectedDailyCount,
    'availableDailyCount': availableDailyCount,
    'missingDailyDates': missingDailyDates,
    'sourceMonthlyFactIds': sourceMonthlyFactIds,
    'missingMonthlyFactIds': missingMonthlyFactIds,
    'metrics': {
      for (final entry in metrics.entries) entry.key: entry.value.toJson(),
    },
    'previousPeriodComparisons': {
      for (final entry in previousPeriodComparisons.entries)
        entry.key: entry.value.toJson(),
    },
    'operationStatusCounts': operationStatusCounts,
    'trainingSessionCount': trainingSessionCount,
    'trainingDays': trainingDays,
    'exercisesPerformed': exercisesPerformed,
    'theoreticalWeightChangeKg': theoreticalWeightChangeKg,
    'actualWeightChangeKg': actualWeightChangeKg,
  };

  factory PeriodicReportFacts.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    return PeriodicReportFacts(
      reportType: PeriodicReportType.parse(json['reportType']),
      periodId: ReportSyncRecordUtils.string(json, 'periodId'),
      startDate: ReportSyncRecordUtils.localDate(json, 'startDate'),
      endDate: ReportSyncRecordUtils.localDate(json, 'endDate'),
      expectedDailyCount: _integer(json['expectedDailyCount']),
      availableDailyCount: _integer(json['availableDailyCount']),
      missingDailyDates: _strings(json['missingDailyDates']),
      sourceMonthlyFactIds: _strings(json['sourceMonthlyFactIds']),
      missingMonthlyFactIds: _strings(json['missingMonthlyFactIds']),
      metrics: _metricFacts(json['metrics']),
      previousPeriodComparisons: _comparisons(
        json['previousPeriodComparisons'],
      ),
      operationStatusCounts: _counts(json['operationStatusCounts']),
      trainingSessionCount: _integer(json['trainingSessionCount']),
      trainingDays: _integer(json['trainingDays']),
      exercisesPerformed: _strings(json['exercisesPerformed']),
      theoreticalWeightChangeKg: _number(json['theoreticalWeightChangeKg']),
      actualWeightChangeKg: _number(json['actualWeightChangeKg']),
    );
  }
}

class PeriodicReportAnalysis {
  static const fields = {
    'body',
    'nutrition',
    'calorieBalance',
    'activity',
    'recovery',
    'training',
    'condition',
    'operation',
    'overallSummary',
    'nextPeriodFocus',
  };

  const PeriodicReportAnalysis({
    required this.body,
    required this.nutrition,
    required this.calorieBalance,
    required this.activity,
    required this.recovery,
    required this.training,
    required this.condition,
    required this.operation,
    required this.overallSummary,
    required this.nextPeriodFocus,
  });

  final String body;
  final String nutrition;
  final String calorieBalance;
  final String activity;
  final String recovery;
  final String training;
  final String condition;
  final String operation;
  final String overallSummary;
  final String nextPeriodFocus;

  Map<String, Object?> toJson() => {
    'body': body,
    'nutrition': nutrition,
    'calorieBalance': calorieBalance,
    'activity': activity,
    'recovery': recovery,
    'training': training,
    'condition': condition,
    'operation': operation,
    'overallSummary': overallSummary,
    'nextPeriodFocus': nextPeriodFocus,
  };

  factory PeriodicReportAnalysis.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    return PeriodicReportAnalysis(
      body: ReportSyncRecordUtils.string(json, 'body'),
      nutrition: ReportSyncRecordUtils.string(json, 'nutrition'),
      calorieBalance: ReportSyncRecordUtils.string(json, 'calorieBalance'),
      activity: ReportSyncRecordUtils.string(json, 'activity'),
      recovery: ReportSyncRecordUtils.string(json, 'recovery'),
      training: ReportSyncRecordUtils.string(json, 'training'),
      condition: ReportSyncRecordUtils.string(json, 'condition'),
      operation: ReportSyncRecordUtils.string(json, 'operation'),
      overallSummary: ReportSyncRecordUtils.string(json, 'overallSummary'),
      nextPeriodFocus: ReportSyncRecordUtils.string(json, 'nextPeriodFocus'),
    );
  }
}

class PeriodicReportRevision {
  const PeriodicReportRevision({
    required this.revision,
    required this.facts,
    required this.analysis,
    required this.sourceDigest,
    required this.responseDigest,
    required this.exchangeId,
    required this.importedAt,
  });

  final int revision;
  final PeriodicReportFacts facts;
  final PeriodicReportAnalysis analysis;
  final String sourceDigest;
  final String responseDigest;
  final String exchangeId;
  final DateTime importedAt;

  Map<String, Object?> toJson() => {
    'revision': revision,
    'facts': facts.toJson(),
    'analysis': analysis.toJson(),
    'sourceDigest': sourceDigest,
    'responseDigest': responseDigest,
    'exchangeId': exchangeId,
    'importedAt': importedAt.toUtc().toIso8601String(),
  };

  factory PeriodicReportRevision.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, const {
      'revision',
      'facts',
      'analysis',
      'sourceDigest',
      'responseDigest',
      'exchangeId',
      'importedAt',
    });
    return PeriodicReportRevision(
      revision: _integer(json['revision']),
      facts: PeriodicReportFacts.fromJson(_map(json['facts'])),
      analysis: PeriodicReportAnalysis.fromJson(_map(json['analysis'])),
      sourceDigest: ReportSyncRecordUtils.digest(json, 'sourceDigest'),
      responseDigest: ReportSyncRecordUtils.digest(json, 'responseDigest'),
      exchangeId: ReportSyncRecordUtils.string(json, 'exchangeId'),
      importedAt: ReportSyncRecordUtils.date(json, 'importedAt'),
    );
  }
}

class PeriodicReportRecord {
  static const currentRecordVersion = 1;

  PeriodicReportRecord({
    required this.id,
    this.recordVersion = currentRecordVersion,
    required this.reportType,
    required this.periodStart,
    required this.periodEnd,
    required this.revision,
    required this.facts,
    required this.analysis,
    required this.sourceDigest,
    required this.responseDigest,
    required this.exchangeId,
    required this.importedAt,
    required this.updatedAt,
    required Iterable<PeriodicReportRevision> previousRevisions,
    Iterable<Map<String, Object?>> archivedRevisions = const [],
  }) : previousRevisions = List.unmodifiable(previousRevisions),
       archivedRevisions = List.unmodifiable(
         archivedRevisions.map(Map<String, Object?>.unmodifiable),
       ) {
    if (recordVersion != currentRecordVersion ||
        revision < 1 ||
        id != facts.periodId ||
        reportType != facts.reportType ||
        periodStart != facts.startDate ||
        periodEnd != facts.endDate ||
        this.archivedRevisions.length + previousRevisions.length !=
            revision - 1 ||
        this.archivedRevisions.indexed.any(
          (entry) =>
              entry.$2['revision'] != entry.$1 + 1 ||
              !ReportSyncRecordUtils.isArchiveBodyDigest(
                entry.$2['bodyDigest'],
              ),
        ) ||
        previousRevisions.indexed.any(
          (entry) =>
              entry.$2.revision != this.archivedRevisions.length + entry.$1 + 1,
        )) {
      throw const FormatException('Periodic report record is invalid.');
    }
  }

  final String id;
  final int recordVersion;
  final PeriodicReportType reportType;
  final String periodStart;
  final String periodEnd;
  final int revision;
  final PeriodicReportFacts facts;
  final PeriodicReportAnalysis analysis;
  final String sourceDigest;
  final String responseDigest;
  final String exchangeId;
  final DateTime importedAt;
  final DateTime updatedAt;
  final List<PeriodicReportRevision> previousRevisions;
  final List<Map<String, Object?>> archivedRevisions;

  factory PeriodicReportRecord.initial({
    required PeriodicReportFacts facts,
    required PeriodicReportAnalysis analysis,
    required String sourceDigest,
    required String responseDigest,
    required String exchangeId,
    required DateTime timestamp,
  }) => PeriodicReportRecord(
    id: facts.periodId,
    reportType: facts.reportType,
    periodStart: facts.startDate,
    periodEnd: facts.endDate,
    revision: 1,
    facts: facts,
    analysis: analysis,
    sourceDigest: sourceDigest,
    responseDigest: responseDigest,
    exchangeId: exchangeId,
    importedAt: timestamp.toUtc(),
    updatedAt: timestamp.toUtc(),
    previousRevisions: const [],
    archivedRevisions: const [],
  );

  PeriodicReportRecord revise({
    required PeriodicReportFacts facts,
    required PeriodicReportAnalysis analysis,
    required String sourceDigest,
    required String responseDigest,
    required String exchangeId,
    required DateTime timestamp,
  }) => PeriodicReportRecord(
    id: id,
    reportType: reportType,
    periodStart: periodStart,
    periodEnd: periodEnd,
    revision: revision + 1,
    facts: facts,
    analysis: analysis,
    sourceDigest: sourceDigest,
    responseDigest: responseDigest,
    exchangeId: exchangeId,
    importedAt: timestamp.toUtc(),
    updatedAt: timestamp.toUtc(),
    previousRevisions: [
      ...previousRevisions,
      PeriodicReportRevision(
        revision: revision,
        facts: this.facts,
        analysis: this.analysis,
        sourceDigest: this.sourceDigest,
        responseDigest: this.responseDigest,
        exchangeId: this.exchangeId,
        importedAt: importedAt,
      ),
    ],
    archivedRevisions: archivedRevisions,
  );

  Map<String, Object?> toRecord() => {
    'id': id,
    'recordVersion': recordVersion,
    'reportType': reportType.stableId,
    'periodStart': periodStart,
    'periodEnd': periodEnd,
    'revision': revision,
    'facts': facts.toJson(),
    'analysis': analysis.toJson(),
    'sourceDigest': sourceDigest,
    'responseDigest': responseDigest,
    'exchangeId': exchangeId,
    'importedAt': importedAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'previousRevisions': [
      for (final value in previousRevisions) value.toJson(),
    ],
    if (archivedRevisions.isNotEmpty) 'archivedRevisions': archivedRevisions,
  };

  factory PeriodicReportRecord.fromRecord(Map<String, Object?> json) {
    final expectedFields = <String>{
      'id',
      'recordVersion',
      'reportType',
      'periodStart',
      'periodEnd',
      'revision',
      'facts',
      'analysis',
      'sourceDigest',
      'responseDigest',
      'exchangeId',
      'importedAt',
      'updatedAt',
      'previousRevisions',
      if (json.containsKey('archivedRevisions')) 'archivedRevisions',
    };
    ReportSyncRecordUtils.exactFields(json, expectedFields);
    final revisions = json['previousRevisions'];
    if (revisions is! List || revisions.any((value) => value is! Map)) {
      throw const FormatException('Invalid periodic report revisions.');
    }
    final archived = json['archivedRevisions'] ?? const <Object?>[];
    if (archived is! List || archived.any((value) => value is! Map)) {
      throw const FormatException('Invalid archived periodic revisions.');
    }
    return PeriodicReportRecord(
      id: ReportSyncRecordUtils.string(json, 'id'),
      recordVersion: _integer(json['recordVersion']),
      reportType: PeriodicReportType.parse(json['reportType']),
      periodStart: ReportSyncRecordUtils.localDate(json, 'periodStart'),
      periodEnd: ReportSyncRecordUtils.localDate(json, 'periodEnd'),
      revision: _integer(json['revision']),
      facts: PeriodicReportFacts.fromJson(_map(json['facts'])),
      analysis: PeriodicReportAnalysis.fromJson(_map(json['analysis'])),
      sourceDigest: ReportSyncRecordUtils.digest(json, 'sourceDigest'),
      responseDigest: ReportSyncRecordUtils.digest(json, 'responseDigest'),
      exchangeId: ReportSyncRecordUtils.string(json, 'exchangeId'),
      importedAt: ReportSyncRecordUtils.date(json, 'importedAt'),
      updatedAt: ReportSyncRecordUtils.date(json, 'updatedAt'),
      previousRevisions: [
        for (final value in revisions)
          PeriodicReportRevision.fromJson(
            Map<String, Object?>.from(value as Map),
          ),
      ],
      archivedRevisions: [
        for (final value in archived) Map<String, Object?>.from(value as Map),
      ],
    );
  }
}

double? _number(Object? value) => value == null
    ? null
    : value is num
    ? value.toDouble()
    : throw const FormatException('Expected a numeric value.');

int _integer(Object? value) => value is int
    ? value
    : throw const FormatException('Expected an integer value.');

Map<String, Object?> _map(Object? value) => value is Map
    ? Map<String, Object?>.from(value)
    : throw const FormatException('Expected an object.');

List<String> _strings(Object? value) =>
    value is List &&
        value.every((item) => item is String && item.trim().isNotEmpty)
    ? List<String>.unmodifiable(value.cast<String>())
    : throw const FormatException('Expected a string array.');

Map<String, PeriodicMetricFact> _metricFacts(Object? value) => {
  for (final entry in _map(value).entries)
    entry.key: PeriodicMetricFact.fromJson(_map(entry.value)),
};

Map<String, PeriodicMetricComparison> _comparisons(Object? value) => {
  for (final entry in _map(value).entries)
    entry.key: PeriodicMetricComparison.fromJson(_map(entry.value)),
};

Map<String, int> _counts(Object? value) => {
  for (final entry in _map(value).entries) entry.key: _integer(entry.value),
};

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
