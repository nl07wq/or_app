class StatusReportSyncSourceException implements Exception {
  const StatusReportSyncSourceException({
    required this.code,
    required this.stage,
    required this.message,
    required this.operationDate,
    this.field,
  });

  final String code;
  final String stage;
  final String message;
  final String operationDate;
  final String? field;

  @override
  String toString() => '$code: $message';
}

class StatusReportSyncBodySource {
  const StatusReportSyncBodySource({
    required this.weightKg,
    required this.bodyFatPercent,
  });

  final double weightKg;
  final double bodyFatPercent;
}

class StatusReportSyncRecoverySource {
  const StatusReportSyncRecoverySource({
    required this.sleepDurationMinutes,
    required this.sleepScore,
  });

  final int sleepDurationMinutes;
  final int sleepScore;
}

class StatusReportSyncConditionSource {
  const StatusReportSyncConditionSource({
    required this.footPainLevel,
    required this.condition,
    required this.notes,
  });

  final int footPainLevel;
  final int? condition;
  final String? notes;
}

class StatusReportSyncWorkSource {
  const StatusReportSyncWorkSource({
    required this.workType,
    required this.startTime,
    required this.endTime,
    required this.breakDurationMinutes,
    required this.workHours,
  });

  final String workType;
  final String? startTime;
  final String? endTime;
  final int? breakDurationMinutes;
  final double workHours;
}

class StatusReportSyncPreviousDayComparison {
  const StatusReportSyncPreviousDayComparison({
    required this.previousOperationDate,
    required this.previousStatusAvailable,
    required this.weightDifferenceKg,
    required this.bodyFatDifferencePoint,
  });

  final String previousOperationDate;
  final bool previousStatusAvailable;
  final String? weightDifferenceKg;
  final String? bodyFatDifferencePoint;
}

class StatusReportSyncSource {
  const StatusReportSyncSource({
    required this.operationDate,
    required this.sourceRecordId,
    required this.sourceRecordVersion,
    required this.body,
    required this.recovery,
    required this.condition,
    required this.work,
    required this.previousCarryoverConfirmed,
    required this.previousDayComparison,
  });

  final String operationDate;
  final String sourceRecordId;
  final int sourceRecordVersion;
  final StatusReportSyncBodySource body;
  final StatusReportSyncRecoverySource recovery;
  final StatusReportSyncConditionSource condition;
  final StatusReportSyncWorkSource work;
  final bool? previousCarryoverConfirmed;
  final StatusReportSyncPreviousDayComparison previousDayComparison;
}

class StatusReportSyncSourceExport {
  const StatusReportSyncSourceExport({
    required this.source,
    required this.exportedAt,
    required this.sourceDigest,
    required this.canonicalText,
    required this.plainText,
  });

  final StatusReportSyncSource source;
  final DateTime exportedAt;
  final String sourceDigest;
  final String canonicalText;
  final String plainText;
}
