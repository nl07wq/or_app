import '../../../core/models/daily_log_confirmation.dart';

enum DailyLogConfirmationLifecycleStatus {
  finalized('finalized'),
  reopened('reopened');

  const DailyLogConfirmationLifecycleStatus(this.stableId);

  final String stableId;

  static DailyLogConfirmationLifecycleStatus fromStableId(Object? value) {
    if (value is! String) {
      throw const FormatException(
        'Invalid Daily Log Confirmation lifecycleStatus.',
      );
    }
    return values.firstWhere(
      (status) => status.stableId == value,
      orElse: () => throw FormatException(
        'Unknown Daily Log Confirmation lifecycleStatus: $value.',
      ),
    );
  }
}

enum DailyLogConfirmationReopenReason {
  userCorrection('userCorrection');

  const DailyLogConfirmationReopenReason(this.stableId);

  final String stableId;

  static DailyLogConfirmationReopenReason fromStableId(Object? value) {
    if (value is! String) {
      throw const FormatException(
        'Invalid Daily Log Confirmation reopenReason.',
      );
    }
    return values.firstWhere(
      (reason) => reason.stableId == value,
      orElse: () => throw FormatException(
        'Unknown Daily Log Confirmation reopenReason: $value.',
      ),
    );
  }
}

class DailyLogConfirmationSourceRecordVersions {
  static const fields = {'status', 'food', 'activity', 'training'};

  final int? status;
  final int? food;
  final int? activity;
  final int? training;

  const DailyLogConfirmationSourceRecordVersions({
    required this.status,
    required this.food,
    required this.activity,
    required this.training,
  });

  const DailyLogConfirmationSourceRecordVersions.unknown()
    : status = null,
      food = null,
      activity = null,
      training = null;

  Map<String, Object?> toJson() => {
    'status': status,
    'food': food,
    'activity': activity,
    'training': training,
  };

  factory DailyLogConfirmationSourceRecordVersions.fromJson(
    Map<String, Object?> json,
  ) {
    _requireExactFields(json, fields, 'sourceRecordVersions');
    return DailyLogConfirmationSourceRecordVersions(
      status: _nullablePositiveInt(json['status'], 'status'),
      food: _nullablePositiveInt(json['food'], 'food'),
      activity: _nullablePositiveInt(json['activity'], 'activity'),
      training: _nullablePositiveInt(json['training'], 'training'),
    );
  }
}

class DailyLogConfirmationRevision {
  static const fields = {
    'revision',
    'snapshot',
    'snapshotDigest',
    'finalizedAt',
    'reopenedAt',
    'sourceRecordVersions',
  };

  final int revision;
  final DailyLogConfirmation snapshot;
  final String snapshotDigest;
  final DateTime finalizedAt;
  final DateTime reopenedAt;
  final DailyLogConfirmationSourceRecordVersions sourceRecordVersions;

  DailyLogConfirmationRevision({
    required this.revision,
    required this.snapshot,
    required this.snapshotDigest,
    required DateTime finalizedAt,
    required DateTime reopenedAt,
    required this.sourceRecordVersions,
  }) : finalizedAt = finalizedAt.toUtc(),
       reopenedAt = reopenedAt.toUtc() {
    if (revision < 1) {
      throw const FormatException(
        'Daily Log Confirmation revision must be positive.',
      );
    }
    _validateDigest(snapshotDigest, 'snapshotDigest');
    if (this.reopenedAt.isBefore(this.finalizedAt)) {
      throw const FormatException(
        'Daily Log Confirmation revision reopenedAt is invalid.',
      );
    }
  }

  Map<String, Object?> toJson() => {
    'revision': revision,
    'snapshot': snapshot.toJson(),
    'snapshotDigest': snapshotDigest,
    'finalizedAt': finalizedAt.toIso8601String(),
    'reopenedAt': reopenedAt.toIso8601String(),
    'sourceRecordVersions': sourceRecordVersions.toJson(),
  };

  factory DailyLogConfirmationRevision.fromJson(Map<String, Object?> json) {
    _requireExactFields(json, fields, 'previousRevisions');
    final revision = json['revision'];
    final snapshot = json['snapshot'];
    final sourceRecordVersions = json['sourceRecordVersions'];
    if (revision is! int || snapshot is! Map || sourceRecordVersions is! Map) {
      throw const FormatException('Invalid Daily Log Confirmation revision.');
    }
    return DailyLogConfirmationRevision(
      revision: revision,
      snapshot: DailyLogConfirmation.fromJson(
        Map<String, dynamic>.from(snapshot),
      ),
      snapshotDigest: _requiredString(json, 'snapshotDigest'),
      finalizedAt: _requiredUtcDate(json, 'finalizedAt'),
      reopenedAt: _requiredUtcDate(json, 'reopenedAt'),
      sourceRecordVersions: DailyLogConfirmationSourceRecordVersions.fromJson(
        Map<String, Object?>.from(sourceRecordVersions),
      ),
    );
  }
}

void _requireExactFields(
  Map<String, Object?> value,
  Set<String> expected,
  String label,
) {
  final actual = value.keys.toSet();
  if (actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw FormatException('Invalid Daily Log Confirmation $label fields.');
  }
}

int? _nullablePositiveInt(Object? value, String field) {
  if (value == null) return null;
  if (value is! int || value < 1) {
    throw FormatException(
      'Invalid Daily Log Confirmation sourceRecordVersions.$field.',
    );
  }
  return value;
}

String _requiredString(Map<String, Object?> value, String field) {
  final result = value[field];
  if (result is! String || result.isEmpty) {
    throw FormatException('Invalid Daily Log Confirmation $field.');
  }
  return result;
}

DateTime _requiredUtcDate(Map<String, Object?> value, String field) {
  final raw = _requiredString(value, field);
  final result = DateTime.tryParse(raw);
  if (result == null || !result.isUtc || !raw.endsWith('Z')) {
    throw FormatException('Invalid Daily Log Confirmation $field.');
  }
  return result;
}

void _validateDigest(String value, String field) {
  if (!RegExp(r'^[0-9a-f]{8}$').hasMatch(value)) {
    throw FormatException('Invalid Daily Log Confirmation $field.');
  }
}
