import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../operation_date/models/operation_local_date.dart';
import '../../operation_date/models/operation_state.dart';
import '../models/operation_sync_history.dart';
import '../models/operation_sync_issue.dart';
import '../models/operation_sync_preview.dart';
import '../models/operation_sync_state.dart';
import '../models/operation_transfer_package.dart';
import '../repository/operation_sync_history_repository.dart';
import '../repository/operation_sync_state_repository.dart';
import 'operation_sync_validator.dart';
import 'operation_transfer_codec.dart';

class OperationSyncCoreService {
  final OperationTransferCodec codec;
  final OperationSyncValidator validator;
  final OperationSyncStateRepository stateRepository;
  final OperationSyncHistoryRepository historyRepository;
  final IndexedDbDatabase database;
  final DateTime Function() _clock;

  OperationSyncCoreService({
    required this.codec,
    required this.validator,
    required this.stateRepository,
    required this.historyRepository,
    required this.database,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  Future<OperationSyncPreview> preview(String rawPackage) async {
    var state = await stateRepository.initializeIfAbsent();
    _requireStartable(state);
    final startedAt = _clock().toUtc();
    final operationId = 'operation-sync:${startedAt.microsecondsSinceEpoch}';
    state = await _move(
      state,
      state.copyWith(
        phase: OperationSyncPhase.reading,
        operationId: operationId,
        packageId: null,
        packageDigest: null,
        sourceType: null,
        transferMode: null,
        startedAt: startedAt,
        checkpoint: null,
        failureCode: null,
        failureDetailCode: null,
        updatedAt: startedAt,
      ),
    );
    try {
      final package = codec.decode(rawPackage);
      final checkpoint = _checkpointFor(package, 'validated');
      state = await _move(
        state,
        state.copyWith(
          phase: OperationSyncPhase.validating,
          packageId: package.packageId,
          packageDigest: package.packageDigest,
          sourceType: package.sourceType.stableId,
          transferMode: package.transferMode.stableId,
          checkpoint: checkpoint,
          updatedAt: _clock().toUtc(),
        ),
      );
      final preview = await validator.preview(package);
      state = await _move(
        state,
        state.copyWith(
          phase: preview.canApply
              ? OperationSyncPhase.previewReady
              : OperationSyncPhase.failed,
          failureCode: preview.canApply
              ? null
              : preview.issues
                    .firstWhere(
                      (issue) =>
                          issue.level == OperationSyncIssueLevel.blocking,
                    )
                    .code,
          failureDetailCode: preview.canApply ? null : 'previewBlocked',
          updatedAt: _clock().toUtc(),
        ),
      );
      if (!preview.canApply) {
        await _recordHistory(
          state: state,
          package: package,
          preview: preview,
          result: OperationSyncHistoryResult.failed,
          failureCode: state.failureCode,
          isRecoveryExecution: false,
        );
      }
      return preview;
    } on OperationSyncException catch (error) {
      await _fail(state, error.code, error.code.stableId);
      rethrow;
    } catch (_) {
      await _fail(
        state,
        OperationSyncIssueCode.integrityFailure,
        'unexpectedCoreFailure',
      );
      rethrow;
    }
  }

  Future<OperationSyncPreview> resumePreview(String rawPackage) async {
    var state = await stateRepository.requireCurrent();
    final history = state.operationId == null
        ? null
        : await historyRepository.readById(state.operationId!);
    final canResume =
        state.requiresRecovery ||
        state.phase == OperationSyncPhase.previewReady ||
        (state.phase == OperationSyncPhase.completed && history == null);
    if (!canResume || state.packageDigest == null || state.checkpoint == null) {
      throw const OperationSyncException(
        OperationSyncIssueCode.processingStateConflict,
        'Operation Sync has no resumable checkpoint.',
      );
    }
    final package = codec.decode(rawPackage);
    if (package.packageDigest != state.packageDigest ||
        package.packageDigest != state.checkpoint!.validatedPackageDigest ||
        !_checkpointMatches(package, state.checkpoint!)) {
      throw const OperationSyncException(
        OperationSyncIssueCode.packageDigestMismatch,
        'Selected package does not match the recovery checkpoint.',
      );
    }
    final preview = await validator.preview(package);
    state = await _move(
      state,
      state.copyWith(
        phase: preview.canApply
            ? OperationSyncPhase.previewReady
            : OperationSyncPhase.recoveryRequired,
        failureCode: preview.canApply
            ? null
            : preview.issues
                  .firstWhere(
                    (issue) => issue.level == OperationSyncIssueLevel.blocking,
                  )
                  .code,
        failureDetailCode: preview.canApply ? null : 'recoveryPreviewBlocked',
        updatedAt: _clock().toUtc(),
      ),
    );
    return preview;
  }

  Future<void> apply({
    required OperationTransferPackage package,
    required OperationSyncPreview preview,
    bool isRecoveryExecution = false,
  }) async {
    if (!preview.canApply || preview.packageDigest != package.packageDigest) {
      throw const OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Operation Sync preview cannot be applied.',
      );
    }
    var state = await stateRepository.requireCurrent();
    if (state.phase != OperationSyncPhase.previewReady ||
        state.packageDigest != package.packageDigest) {
      throw const OperationSyncException(
        OperationSyncIssueCode.operationStateConflict,
        'Operation Sync State is not preview-ready.',
      );
    }
    state = await _move(
      state,
      state.copyWith(
        phase: OperationSyncPhase.applying,
        checkpoint: _checkpointFor(package, 'applying'),
        updatedAt: _clock().toUtc(),
      ),
    );
    final targetOperationState = await validator.operationStateRepository
        ?.requireCurrent();
    final pristineTarget =
        targetOperationState != null &&
        targetOperationState.phase == OperationPhase.open &&
        targetOperationState.revision == 0 &&
        targetOperationState.lastFinalizedDate == null &&
        !await validator.registry.hasAnyTargetRecords();
    final context = OperationSyncInspectionContext(
      package: package,
      targetOperationState: targetOperationState,
      pristineTarget: pristineTarget,
    );
    final transactionStores = <String>{
      ...validator.registry.storeNames,
      if (targetOperationState != null) IndexedDbStoreNames.operationState,
    };
    try {
      await database.runTransaction<void>(
        storeNames: transactionStores,
        mode: IndexedDbTransactionMode.readWrite,
        action: (transaction) async {
          await _applyOperationState(transaction, context);
          var created = 0;
          var noChanges = 0;
          for (final section in package.sections) {
            final adapter = validator.registry.adapterFor(section.module);
            if (adapter == null) {
              throw const OperationSyncException(
                OperationSyncIssueCode.adapterUnavailable,
                'Module adapter is unavailable.',
              );
            }
            final counts = await adapter.apply(
              transaction,
              section.records,
              context,
            );
            created += counts.created;
            noChanges += counts.noChanges;
          }
          if (created != preview.createCount ||
              noChanges != preview.noChangeCount) {
            throw const OperationSyncException(
              OperationSyncIssueCode.operationStateConflict,
              'Target records changed after preview.',
            );
          }
          await _verify(transaction, package);
        },
      );
      state = await _move(
        state,
        state.copyWith(
          phase: OperationSyncPhase.verifying,
          checkpoint: _checkpointFor(package, 'verifying'),
          updatedAt: _clock().toUtc(),
        ),
      );
      await database.runTransaction<void>(
        storeNames: transactionStores,
        mode: IndexedDbTransactionMode.readOnly,
        action: (transaction) async {
          await _verifyOperationState(transaction, context);
          await _verify(transaction, package);
        },
      );
    } on OperationSyncException catch (error) {
      await _requireRecovery(state, error.code, error.code.stableId);
      rethrow;
    } catch (_) {
      await _requireRecovery(
        state,
        OperationSyncIssueCode.integrityFailure,
        'moduleApplyFailure',
      );
      rethrow;
    }
    final completedAt = _clock().toUtc();
    final completed = await _move(
      state,
      state.copyWith(
        phase: OperationSyncPhase.completed,
        checkpoint: _checkpointFor(package, 'verified'),
        updatedAt: completedAt,
      ),
    );
    await _recordHistory(
      state: completed,
      package: package,
      preview: preview,
      result: OperationSyncHistoryResult.success,
      isRecoveryExecution: isRecoveryExecution,
    );
  }

  static bool _checkpointMatches(
    OperationTransferPackage package,
    OperationSyncCheckpoint checkpoint,
  ) {
    final sectionDigests = {
      for (final section in package.sections)
        section.module: section.sectionDigest,
    };
    final recordDigests = [
      for (final section in package.sections)
        for (final record in section.records) record.recordDigest,
    ];
    if (sectionDigests.length != checkpoint.expectedSectionDigests.length ||
        recordDigests.length != checkpoint.expectedRecordDigests.length) {
      return false;
    }
    for (final entry in sectionDigests.entries) {
      if (checkpoint.expectedSectionDigests[entry.key] != entry.value) {
        return false;
      }
    }
    for (var index = 0; index < recordDigests.length; index++) {
      if (checkpoint.expectedRecordDigests[index] != recordDigests[index]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _applyOperationState(
    IndexedDbTransaction transaction,
    OperationSyncInspectionContext context,
  ) async {
    final expected = context.targetOperationState;
    if (expected == null) return;
    final stored = await transaction.findById(
      IndexedDbStoreNames.operationState,
      OperationState.canonicalId,
    );
    if (stored == null) {
      throw const OperationSyncException(
        OperationSyncIssueCode.operationStateConflict,
        'Target Operation State is missing.',
      );
    }
    final current = OperationState.fromRecord(stored);
    if (!_sameOperationState(current, expected)) {
      throw const OperationSyncException(
        OperationSyncIssueCode.operationStateConflict,
        'Target Operation State changed after preview.',
      );
    }
    if (!context.pristineTarget) return;
    final now = _clock().toUtc();
    final next = OperationState(
      operationDate: OperationLocalDate.parse(
        context.package.manifest.sourceOperationDate,
      ),
      revision: current.revision + 1,
      lastFinalizedDate:
          context.package.manifest.sourceLastFinalizedDate == null
          ? null
          : OperationLocalDate.parse(
              context.package.manifest.sourceLastFinalizedDate!,
            ),
      createdAt: current.createdAt,
      updatedAt: now.isAfter(current.updatedAt)
          ? now
          : current.updatedAt.add(const Duration(microseconds: 1)),
    );
    await transaction.put(IndexedDbStoreNames.operationState, next.toRecord());
    final readBack = await transaction.findById(
      IndexedDbStoreNames.operationState,
      OperationState.canonicalId,
    );
    if (readBack == null ||
        !_sameOperationState(OperationState.fromRecord(readBack), next)) {
      throw const OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Operation State read-back verification failed.',
      );
    }
  }

  Future<void> _verifyOperationState(
    IndexedDbTransaction transaction,
    OperationSyncInspectionContext context,
  ) async {
    final expected = context.targetOperationState;
    if (expected == null) return;
    final stored = await transaction.findById(
      IndexedDbStoreNames.operationState,
      OperationState.canonicalId,
    );
    if (stored == null) {
      throw const OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Operation State read-back is missing.',
      );
    }
    final actual = OperationState.fromRecord(stored);
    if (context.pristineTarget) {
      if (actual.phase != OperationPhase.open ||
          actual.operationDate.value !=
              context.package.manifest.sourceOperationDate ||
          actual.lastFinalizedDate?.value !=
              context.package.manifest.sourceLastFinalizedDate) {
        throw const OperationSyncException(
          OperationSyncIssueCode.integrityFailure,
          'Reconstructed Operation State does not match the source checkpoint.',
        );
      }
    } else if (!_sameOperationState(actual, expected)) {
      throw const OperationSyncException(
        OperationSyncIssueCode.operationStateConflict,
        'Existing target Operation State was modified.',
      );
    }
  }

  static bool _sameOperationState(OperationState first, OperationState second) {
    return first.id == second.id &&
        first.recordVersion == second.recordVersion &&
        first.revision == second.revision &&
        first.hasSameMutableContent(second) &&
        first.createdAt == second.createdAt &&
        first.updatedAt == second.updatedAt;
  }

  Future<void> _verify(
    IndexedDbTransaction transaction,
    OperationTransferPackage package,
  ) async {
    var verifiedCount = 0;
    for (final section in package.sections) {
      final adapter = validator.registry.adapterFor(section.module);
      if (adapter == null ||
          !await adapter.verify(transaction, section.records)) {
        throw const OperationSyncException(
          OperationSyncIssueCode.integrityFailure,
          'Operation Sync read-back verification failed.',
        );
      }
      verifiedCount += section.records.length;
    }
    if (verifiedCount != package.manifest.recordCount) {
      throw const OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Operation Sync read-back record count does not match.',
      );
    }
  }

  OperationSyncCheckpoint _checkpointFor(
    OperationTransferPackage package,
    String status,
  ) {
    return OperationSyncCheckpoint(
      validatedPackageDigest: package.packageDigest,
      expectedSectionDigests: {
        for (final section in package.sections)
          section.module: section.sectionDigest,
      },
      expectedRecordDigests: [
        for (final section in package.sections)
          for (final record in section.records) record.recordDigest,
      ],
      appliedSectionIds: status == 'verified'
          ? [for (final section in package.sections) section.module]
          : const [],
      verificationStatus: status,
    );
  }

  Future<OperationSyncState> _move(
    OperationSyncState current,
    OperationSyncState next,
  ) {
    return stateRepository.guardedUpdate(
      expectedRevision: current.revision,
      next: next,
    );
  }

  Future<void> _fail(
    OperationSyncState state,
    OperationSyncIssueCode code,
    String detail,
  ) async {
    await _move(
      state,
      state.copyWith(
        phase: OperationSyncPhase.failed,
        failureCode: code,
        failureDetailCode: detail,
        updatedAt: _clock().toUtc(),
      ),
    );
  }

  Future<void> _requireRecovery(
    OperationSyncState state,
    OperationSyncIssueCode code,
    String detail,
  ) async {
    await _move(
      state,
      state.copyWith(
        phase: OperationSyncPhase.recoveryRequired,
        failureCode: code,
        failureDetailCode: detail,
        updatedAt: _clock().toUtc(),
      ),
    );
  }

  Future<void> _recordHistory({
    required OperationSyncState state,
    required OperationTransferPackage package,
    required OperationSyncPreview preview,
    required OperationSyncHistoryResult result,
    required bool isRecoveryExecution,
    OperationSyncIssueCode? failureCode,
  }) async {
    final completedAt = _clock().toUtc();
    await historyRepository.create(
      OperationSyncHistory(
        operationId: state.operationId!,
        packageId: package.packageId,
        packageDigest: package.packageDigest,
        sourceType: package.sourceType.stableId,
        transferMode: package.transferMode.stableId,
        startedAt: state.startedAt!,
        completedAt: completedAt.isBefore(state.startedAt!)
            ? state.startedAt!
            : completedAt,
        moduleIds: [for (final section in package.sections) section.module],
        recordCount: preview.recordCount,
        createCount: preview.createCount,
        noChangeCount: preview.noChangeCount,
        conflictCount: preview.conflictCount,
        quarantineCount: 0,
        result: result,
        failureCode: failureCode,
        isRecoveryExecution: isRecoveryExecution,
      ),
    );
  }

  static void _requireStartable(OperationSyncState state) {
    if (state.requiresRecovery ||
        state.phase == OperationSyncPhase.previewReady) {
      throw const OperationSyncException(
        OperationSyncIssueCode.processingStateConflict,
        'Operation Sync State is already active.',
      );
    }
  }
}
