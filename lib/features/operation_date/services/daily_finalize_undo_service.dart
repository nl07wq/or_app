import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../activity/models/activity_draft.dart';
import '../../daily_log_confirmation/models/persisted_daily_log_confirmation_record.dart';
import '../../daily_log_confirmation/services/daily_log_confirmation_source_snapshot.dart';
import '../../daily_aggregate/repository/indexed_db_daily_aggregate_repository.dart';
import '../../import_export/services/backup_canonical_codec.dart';
import '../models/operation_local_date.dart';
import '../models/operation_state.dart';

enum DailyFinalizeUndoErrorCode {
  noUndoableFinalize,
  operationStateNotOpen,
  targetIsNotPreviousDay,
  targetConfirmationMissing,
  targetConfirmationInvalid,
  currentDateHasRecords,
  currentDateHasDraft,
  revisionConflict,
  readBackFailed,
  transactionFailed,
}

class DailyFinalizeUndoException implements Exception {
  const DailyFinalizeUndoException({
    required this.code,
    required this.stage,
    required this.message,
    this.cause,
  });

  final DailyFinalizeUndoErrorCode code;
  final String stage;
  final String message;
  final Object? cause;

  @override
  String toString() => '$code [$stage]: $message';
}

class DailyFinalizeUndoInspection {
  const DailyFinalizeUndoInspection({
    required this.currentOperationDate,
    required this.targetDate,
    required this.canUndo,
    required this.revision,
    required this.isAwaitingDailyClose,
    this.blockingError,
  });

  final String currentOperationDate;
  final String targetDate;
  final bool canUndo;
  final int revision;
  final bool isAwaitingDailyClose;
  final DailyFinalizeUndoException? blockingError;
}

class DailyFinalizeUndoResult {
  const DailyFinalizeUndoResult({
    required this.restoredOperationDate,
    required this.revision,
  });

  final String restoredOperationDate;
  final int revision;
}

class DailyFinalizeUndoService {
  static const _stores = [
    IndexedDbStoreNames.operationState,
    IndexedDbStoreNames.dailyLogConfirmations,
    IndexedDbStoreNames.statusRecords,
    IndexedDbStoreNames.foodRecords,
    IndexedDbStoreNames.activityRecords,
    IndexedDbStoreNames.activityDrafts,
    IndexedDbStoreNames.trainingRecords,
    IndexedDbStoreNames.dailyAggregateRecords,
  ];

  DailyFinalizeUndoService(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      _sourceReader = DailyLogConfirmationSourceSnapshotReader(_database);

  final IndexedDbDatabase _database;
  final DateTime Function() _now;
  final DailyLogConfirmationSourceSnapshotReader _sourceReader;

  Future<DailyFinalizeUndoInspection> inspect() async {
    try {
      return await _database.runTransaction(
        storeNames: _stores,
        mode: IndexedDbTransactionMode.readOnly,
        action: (transaction) async {
          final context = await _inspect(transaction);
          return DailyFinalizeUndoInspection(
            currentOperationDate: context.state.operationDate.value,
            targetDate: context.target.value,
            canUndo: true,
            revision: context.state.revision,
            isAwaitingDailyClose: context.isAwaitingDailyClose,
          );
        },
      );
    } on DailyFinalizeUndoException catch (error) {
      final state = await _requireStateOutsideTransaction();
      return DailyFinalizeUndoInspection(
        currentOperationDate: state.operationDate.value,
        targetDate: state.phase == OperationPhase.awaitingDebrief
            ? state.operationDate.value
            : state.undoableFinalizeDate?.value ?? '',
        canUndo: false,
        revision: state.revision,
        isAwaitingDailyClose: state.phase == OperationPhase.awaitingDebrief,
        blockingError: error,
      );
    }
  }

  Future<DailyFinalizeUndoResult> undo({required int expectedRevision}) async {
    try {
      return await _database.runTransaction(
        storeNames: _stores,
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          final context = await _inspect(transaction);
          if (context.state.revision != expectedRevision) {
            throw const DailyFinalizeUndoException(
              code: DailyFinalizeUndoErrorCode.revisionConflict,
              stage: 'precondition',
              message: 'Operation Stateが変更されています。',
            );
          }

          final sourceBefore = await _sourceStoreDigests(transaction);
          final confirmationsBefore = await transaction.findAll(
            IndexedDbStoreNames.dailyLogConfirmations,
          );
          final otherConfirmationsBefore = _confirmationDigest(
            confirmationsBefore,
            excludedId: context.targetConfirmation.id,
          );

          await transaction.deleteById(
            IndexedDbStoreNames.dailyLogConfirmations,
            context.targetConfirmation.id,
          );
          await IndexedDbDailyAggregateRepository(
            _database,
          ).deleteByDateInTransaction(transaction, context.target.value);

          final nextState = context.isAwaitingDailyClose
              ? context.state.copyWith(
                  phase: OperationPhase.open,
                  revision: context.state.revision + 1,
                  clearActiveAttempt: true,
                  updatedAt: _nextTimestamp(context.state.updatedAt),
                )
              : OperationState(
                  operationDate: context.target,
                  phase: OperationPhase.open,
                  revision: context.state.revision + 1,
                  lastFinalizedDate: null,
                  undoableFinalizeDate: null,
                  undoableFinalizeConfirmationId: null,
                  undoableFinalizeCreatedAt: null,
                  activeAttempt: null,
                  createdAt: context.state.createdAt,
                  updatedAt: _nextTimestamp(context.state.updatedAt),
                );
          await transaction.put(
            IndexedDbStoreNames.operationState,
            nextState.toRecord(),
          );

          final targetReadBack = await transaction.findById(
            IndexedDbStoreNames.dailyLogConfirmations,
            context.targetConfirmation.id,
          );
          if (targetReadBack != null) {
            throw const DailyFinalizeUndoException(
              code: DailyFinalizeUndoErrorCode.readBackFailed,
              stage: 'confirmationReadBack',
              message: '対象Confirmationの削除を確認できません。',
            );
          }

          final stateReadBack = await _requireState(transaction);
          if (!_sameRecord(stateReadBack.toRecord(), nextState.toRecord())) {
            throw const DailyFinalizeUndoException(
              code: DailyFinalizeUndoErrorCode.readBackFailed,
              stage: 'operationStateReadBack',
              message: 'Operation Stateの復元確認に失敗しました。',
            );
          }

          final confirmationsAfter = await transaction.findAll(
            IndexedDbStoreNames.dailyLogConfirmations,
          );
          final otherConfirmationsAfter = _confirmationDigest(
            confirmationsAfter,
            excludedId: context.targetConfirmation.id,
          );
          if (confirmationsAfter.length != confirmationsBefore.length - 1 ||
              otherConfirmationsAfter != otherConfirmationsBefore) {
            throw const DailyFinalizeUndoException(
              code: DailyFinalizeUndoErrorCode.readBackFailed,
              stage: 'otherConfirmationsReadBack',
              message: '対象外Confirmationの不変性確認に失敗しました。',
            );
          }

          final sourceAfter = await _sourceStoreDigests(transaction);
          if (!_sameStringMap(sourceBefore, sourceAfter)) {
            throw const DailyFinalizeUndoException(
              code: DailyFinalizeUndoErrorCode.readBackFailed,
              stage: 'sourceReadBack',
              message: '日次Source Recordの不変性確認に失敗しました。',
            );
          }

          return DailyFinalizeUndoResult(
            restoredOperationDate: nextState.operationDate.value,
            revision: nextState.revision,
          );
        },
      );
    } on DailyFinalizeUndoException {
      rethrow;
    } catch (error) {
      throw DailyFinalizeUndoException(
        code: DailyFinalizeUndoErrorCode.transactionFailed,
        stage: 'transaction',
        message: 'Undo Transactionに失敗しました。',
        cause: error,
      );
    }
  }

  Future<_UndoContext> _inspect(IndexedDbTransaction transaction) async {
    final state = await _requireState(transaction);
    final isAwaitingDailyClose = state.phase == OperationPhase.awaitingDebrief;
    if (!isAwaitingDailyClose &&
        (state.phase != OperationPhase.open || state.activeAttempt != null)) {
      throw const DailyFinalizeUndoException(
        code: DailyFinalizeUndoErrorCode.operationStateNotOpen,
        stage: 'operationState',
        message: 'Operation StateがUNDO可能な通常状態ではありません。',
      );
    }
    final target = isAwaitingDailyClose
        ? state.operationDate
        : state.undoableFinalizeDate;
    final confirmationId = isAwaitingDailyClose
        ? state.activeAttempt?.confirmationId
        : state.undoableFinalizeConfirmationId;
    if (target == null || confirmationId == null) {
      throw const DailyFinalizeUndoException(
        code: DailyFinalizeUndoErrorCode.noUndoableFinalize,
        stage: 'operationState',
        message: '取り消せる直前のFINALIZEはありません。',
      );
    }
    if (!isAwaitingDailyClose && target != state.operationDate.addDays(-1)) {
      throw const DailyFinalizeUndoException(
        code: DailyFinalizeUndoErrorCode.targetIsNotPreviousDay,
        stage: 'operationState',
        message: '直前日のFINALIZEだけを取り消せます。',
      );
    }

    final rawConfirmation = await transaction.findById(
      IndexedDbStoreNames.dailyLogConfirmations,
      confirmationId,
    );
    if (rawConfirmation == null) {
      throw const DailyFinalizeUndoException(
        code: DailyFinalizeUndoErrorCode.targetConfirmationMissing,
        stage: 'targetConfirmation',
        message: 'UNDO対象のConfirmationがありません。',
      );
    }
    late final PersistedDailyLogConfirmationRecord targetConfirmation;
    try {
      targetConfirmation = PersistedDailyLogConfirmationRecord.fromRecord(
        rawConfirmation,
      );
    } on FormatException catch (error) {
      throw DailyFinalizeUndoException(
        code: DailyFinalizeUndoErrorCode.targetConfirmationInvalid,
        stage: 'confirmationValidation',
        message: 'UNDO対象のConfirmationを正常に読み込めません。',
        cause: error,
      );
    }
    if (targetConfirmation.id != confirmationId ||
        targetConfirmation.localDate != target.value) {
      throw const DailyFinalizeUndoException(
        code: DailyFinalizeUndoErrorCode.targetConfirmationInvalid,
        stage: 'confirmationIdentity',
        message: 'UNDO対象のConfirmation IDまたは日付が一致しません。',
      );
    }

    if (!isAwaitingDailyClose) {
      final currentSources = await _sourceReader.readInTransaction(
        transaction,
        state.operationDate.value,
      );
      if (currentSources.records.isNotEmpty) {
        throw const DailyFinalizeUndoException(
          code: DailyFinalizeUndoErrorCode.currentDateHasRecords,
          stage: 'currentDateSources',
          message: '現在のOperation Dateに入力済みデータがあります。',
        );
      }
      final drafts = await transaction.findAll(
        IndexedDbStoreNames.activityDrafts,
      );
      for (final raw in drafts) {
        if (raw['localDate'] != state.operationDate.value) continue;
        ActivityDraft.fromRecord(raw);
        throw const DailyFinalizeUndoException(
          code: DailyFinalizeUndoErrorCode.currentDateHasDraft,
          stage: 'currentDateDraft',
          message: '現在のOperation DateにACTIVITY Draftがあります。',
        );
      }
    }

    return _UndoContext(
      state: state,
      target: target,
      targetConfirmation: targetConfirmation,
      isAwaitingDailyClose: isAwaitingDailyClose,
    );
  }

  Future<OperationState> _requireState(IndexedDbTransaction transaction) async {
    final records = await transaction.findAll(
      IndexedDbStoreNames.operationState,
    );
    if (records.length != 1) {
      throw const DailyFinalizeUndoException(
        code: DailyFinalizeUndoErrorCode.operationStateNotOpen,
        stage: 'operationState',
        message: 'Operation Stateが一意ではありません。',
      );
    }
    try {
      return OperationState.fromRecord(records.single);
    } on FormatException catch (error) {
      throw DailyFinalizeUndoException(
        code: DailyFinalizeUndoErrorCode.operationStateNotOpen,
        stage: 'operationStateValidation',
        message: 'Operation Stateを正常に読み込めません。',
        cause: error,
      );
    }
  }

  Future<OperationState> _requireStateOutsideTransaction() async {
    final records = await _database.findAll(IndexedDbStoreNames.operationState);
    if (records.length != 1) {
      throw StateError('Operation State is not unique.');
    }
    return OperationState.fromRecord(records.single);
  }

  Future<Map<String, String>> _sourceStoreDigests(
    IndexedDbTransaction transaction,
  ) async {
    final result = <String, String>{};
    for (final store in DailyLogConfirmationSourceSnapshotReader.stores) {
      result[store] = _recordsDigest(await transaction.findAll(store));
    }
    result[IndexedDbStoreNames.activityDrafts] = _recordsDigest(
      await transaction.findAll(IndexedDbStoreNames.activityDrafts),
    );
    return result;
  }

  String _confirmationDigest(
    Iterable<Map<String, Object?>> records, {
    required String excludedId,
  }) => _recordsDigest(
    records.where((record) => record['id'] != excludedId).toList(),
  );

  String _recordsDigest(List<Map<String, Object?>> records) {
    final encoded = [
      for (final record in records) BackupCanonicalCodec.encode(record),
    ]..sort();
    return BackupCanonicalCodec.digest(encoded);
  }

  DateTime _nextTimestamp(DateTime current) {
    final now = _now().toUtc();
    return now.isAfter(current)
        ? now
        : current.add(const Duration(microseconds: 1));
  }

  bool _sameRecord(Map<String, Object?> first, Map<String, Object?> second) =>
      BackupCanonicalCodec.encode(first) == BackupCanonicalCodec.encode(second);

  bool _sameStringMap(Map<String, String> first, Map<String, String> second) =>
      first.length == second.length &&
      first.entries.every((entry) => second[entry.key] == entry.value);
}

class _UndoContext {
  const _UndoContext({
    required this.state,
    required this.target,
    required this.targetConfirmation,
    required this.isAwaitingDailyClose,
  });

  final OperationState state;
  final OperationLocalDate target;
  final PersistedDailyLogConfirmationRecord targetConfirmation;
  final bool isAwaitingDailyClose;
}
