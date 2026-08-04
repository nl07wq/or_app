import 'daily_log_confirmation_lifecycle.dart';
import 'persisted_daily_log_confirmation_record.dart';

class DailyLogConfirmationLifecycleProjection {
  final bool isFinalized;
  final bool isReopened;
  final bool isEditable;
  final bool isLocked;
  final int? recordVersion;
  final int? revision;

  const DailyLogConfirmationLifecycleProjection._({
    required this.isFinalized,
    required this.isReopened,
    required this.isEditable,
    required this.isLocked,
    required this.recordVersion,
    required this.revision,
  });

  const DailyLogConfirmationLifecycleProjection.notFinalized()
    : this._(
        isFinalized: false,
        isReopened: false,
        isEditable: true,
        isLocked: false,
        recordVersion: null,
        revision: null,
      );

  const DailyLogConfirmationLifecycleProjection.legacyFinalized()
    : this._(
        isFinalized: true,
        isReopened: false,
        isEditable: false,
        isLocked: true,
        recordVersion: PersistedDailyLogConfirmationRecord.legacyRecordVersion,
        revision: 1,
      );

  factory DailyLogConfirmationLifecycleProjection.fromRecord(
    PersistedDailyLogConfirmationRecord? record,
  ) {
    if (record == null) {
      return const DailyLogConfirmationLifecycleProjection.notFinalized();
    }
    final reopened =
        record.projectedLifecycleStatus ==
        DailyLogConfirmationLifecycleStatus.reopened;
    return DailyLogConfirmationLifecycleProjection._(
      isFinalized: !reopened,
      isReopened: reopened,
      isEditable: reopened,
      isLocked: !reopened,
      recordVersion: record.recordVersion,
      revision: record.projectedRevision,
    );
  }
}
