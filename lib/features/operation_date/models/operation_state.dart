import 'operation_active_attempt.dart';
import 'operation_local_date.dart';

enum OperationPhase {
  open,
  finalizing,
  awaitingDebrief,
  finalizedPendingBackup,
  advancing,
}

class OperationState {
  static const canonicalId = 'current';
  static const currentRecordVersion = 1;

  final String id;
  final int recordVersion;
  final OperationLocalDate operationDate;
  final OperationPhase phase;
  final int revision;
  final OperationLocalDate? lastFinalizedDate;
  final OperationLocalDate? undoableFinalizeDate;
  final String? undoableFinalizeConfirmationId;
  final DateTime? undoableFinalizeCreatedAt;
  final OperationActiveAttempt? activeAttempt;
  final DateTime createdAt;
  final DateTime updatedAt;

  OperationState({
    this.id = canonicalId,
    this.recordVersion = currentRecordVersion,
    required this.operationDate,
    this.phase = OperationPhase.open,
    this.revision = 0,
    this.lastFinalizedDate,
    this.undoableFinalizeDate,
    this.undoableFinalizeConfirmationId,
    this.undoableFinalizeCreatedAt,
    this.activeAttempt,
    required this.createdAt,
    required this.updatedAt,
  }) {
    _validate();
  }

  bool get requiresRecovery =>
      phase != OperationPhase.open && phase != OperationPhase.awaitingDebrief;

  bool get hasUndoableFinalize => undoableFinalizeDate != null;

  Map<String, Object?> toRecord() => {
    'id': id,
    'recordVersion': recordVersion,
    'operationDate': operationDate.value,
    'phase': phase.name,
    'revision': revision,
    'lastFinalizedDate': lastFinalizedDate?.value,
    'undoableFinalizeDate': undoableFinalizeDate?.value,
    'undoableFinalizeConfirmationId': undoableFinalizeConfirmationId,
    'undoableFinalizeCreatedAt': undoableFinalizeCreatedAt?.toIso8601String(),
    'activeAttempt': activeAttempt?.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory OperationState.fromRecord(Map<String, Object?> record) {
    final id = record['id'];
    final version = record['recordVersion'];
    final phaseValue = record['phase'];
    final revision = record['revision'];
    final attemptValue = record['activeAttempt'];
    if (id is! String ||
        version is! int ||
        phaseValue is! String ||
        revision is! int ||
        (attemptValue != null && attemptValue is! Map)) {
      throw const FormatException('Invalid operation state record.');
    }
    final phase = OperationPhase.values
        .where((value) => value.name == phaseValue)
        .firstOrNull;
    if (phase == null) {
      throw const FormatException('Invalid operation phase.');
    }
    return OperationState(
      id: id,
      recordVersion: version,
      operationDate: OperationLocalDate.parse(
        _requiredString(record, 'operationDate'),
      ),
      phase: phase,
      revision: revision,
      lastFinalizedDate: record['lastFinalizedDate'] == null
          ? null
          : OperationLocalDate.parse(
              _requiredString(record, 'lastFinalizedDate'),
            ),
      undoableFinalizeDate: record['undoableFinalizeDate'] == null
          ? null
          : OperationLocalDate.parse(
              _requiredString(record, 'undoableFinalizeDate'),
            ),
      undoableFinalizeConfirmationId:
          record['undoableFinalizeConfirmationId'] == null
          ? null
          : _requiredString(record, 'undoableFinalizeConfirmationId'),
      undoableFinalizeCreatedAt: record['undoableFinalizeCreatedAt'] == null
          ? null
          : _requiredUtcDate(record, 'undoableFinalizeCreatedAt'),
      activeAttempt: attemptValue == null
          ? null
          : OperationActiveAttempt.fromJson(
              Map<String, Object?>.from(attemptValue as Map),
            ),
      createdAt: _requiredUtcDate(record, 'createdAt'),
      updatedAt: _requiredUtcDate(record, 'updatedAt'),
    );
  }

  OperationState copyWith({
    OperationLocalDate? operationDate,
    OperationPhase? phase,
    int? revision,
    OperationLocalDate? lastFinalizedDate,
    bool clearLastFinalizedDate = false,
    OperationLocalDate? undoableFinalizeDate,
    String? undoableFinalizeConfirmationId,
    DateTime? undoableFinalizeCreatedAt,
    bool clearUndoableFinalize = false,
    OperationActiveAttempt? activeAttempt,
    bool clearActiveAttempt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OperationState(
      id: id,
      recordVersion: recordVersion,
      operationDate: operationDate ?? this.operationDate,
      phase: phase ?? this.phase,
      revision: revision ?? this.revision,
      lastFinalizedDate: clearLastFinalizedDate
          ? null
          : lastFinalizedDate ?? this.lastFinalizedDate,
      undoableFinalizeDate: clearUndoableFinalize
          ? null
          : undoableFinalizeDate ?? this.undoableFinalizeDate,
      undoableFinalizeConfirmationId: clearUndoableFinalize
          ? null
          : undoableFinalizeConfirmationId ??
                this.undoableFinalizeConfirmationId,
      undoableFinalizeCreatedAt: clearUndoableFinalize
          ? null
          : undoableFinalizeCreatedAt ?? this.undoableFinalizeCreatedAt,
      activeAttempt: clearActiveAttempt
          ? null
          : activeAttempt ?? this.activeAttempt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool hasSameMutableContent(OperationState other) {
    final attemptsMatch =
        activeAttempt == null && other.activeAttempt == null ||
        activeAttempt != null &&
            other.activeAttempt != null &&
            activeAttempt!.hasSameContent(other.activeAttempt!);
    return operationDate == other.operationDate &&
        phase == other.phase &&
        lastFinalizedDate == other.lastFinalizedDate &&
        undoableFinalizeDate == other.undoableFinalizeDate &&
        undoableFinalizeConfirmationId ==
            other.undoableFinalizeConfirmationId &&
        undoableFinalizeCreatedAt == other.undoableFinalizeCreatedAt &&
        attemptsMatch;
  }

  void _validate() {
    if (id != canonicalId ||
        recordVersion != currentRecordVersion ||
        revision < 0 ||
        !createdAt.isUtc ||
        !updatedAt.isUtc ||
        updatedAt.isBefore(createdAt)) {
      throw const FormatException('Invalid operation state record.');
    }
    if (lastFinalizedDate != null &&
        lastFinalizedDate!.compareTo(operationDate) >= 0) {
      throw const FormatException('Invalid last finalized date.');
    }
    final undoFields = [
      undoableFinalizeDate,
      undoableFinalizeConfirmationId,
      undoableFinalizeCreatedAt,
    ];
    final undoFieldCount = undoFields.where((value) => value != null).length;
    if (undoFieldCount != 0 && undoFieldCount != undoFields.length) {
      throw const FormatException('Incomplete undoable finalize state.');
    }
    if (undoableFinalizeDate != null) {
      if (undoableFinalizeDate!.compareTo(operationDate) >= 0 ||
          undoableFinalizeConfirmationId !=
              'confirmation:${undoableFinalizeDate!.value}' ||
          !undoableFinalizeCreatedAt!.isUtc) {
        throw const FormatException('Invalid undoable finalize state.');
      }
      if (phase == OperationPhase.open &&
          operationDate != undoableFinalizeDate!.addDays(1)) {
        throw const FormatException(
          'Open operation does not match undoable finalize date.',
        );
      }
    }
    if (phase == OperationPhase.open) {
      if (activeAttempt != null) {
        throw const FormatException('Open operation cannot have an attempt.');
      }
      return;
    }
    if (activeAttempt == null ||
        activeAttempt!.targetLocalDate != operationDate) {
      throw const FormatException('Operation phase requires a valid attempt.');
    }
    if ((phase == OperationPhase.awaitingDebrief ||
            phase == OperationPhase.finalizedPendingBackup) &&
        (activeAttempt!.confirmationId == null ||
            activeAttempt!.confirmationDigest == null)) {
      throw const FormatException('Prepared operation lacks confirmation.');
    }
    if (phase == OperationPhase.advancing &&
        (activeAttempt!.confirmationId == null ||
            activeAttempt!.confirmationDigest == null ||
            activeAttempt!.backupPackageDigest == null ||
            activeAttempt!.backupGeneratedAt == null)) {
      throw const FormatException('Advancing operation lacks verification.');
    }
  }

  static String _requiredString(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid operation state $key.');
    }
    return value;
  }

  static DateTime _requiredUtcDate(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value is! String) {
      throw FormatException('Invalid operation state $key.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !parsed.isUtc) {
      throw FormatException('Invalid operation state $key.');
    }
    return parsed;
  }
}
