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
  final DateTime Function() _clock;

  OperationSyncCoreService({
    required this.codec,
    required this.validator,
    required this.stateRepository,
    required this.historyRepository,
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
      await _move(
        state,
        state.copyWith(
          phase: OperationSyncPhase.previewReady,
          updatedAt: _clock().toUtc(),
        ),
      );
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

  /// Core acceptance hook only. Production has an empty adapter registry, so
  /// this path cannot write module records until a later approved task.
  Future<void> applyForTesting({
    required OperationTransferPackage package,
    required OperationSyncPreview preview,
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
    for (final section in package.sections) {
      final adapter = validator.registry.adapterFor(section.module);
      if (adapter == null) {
        throw const OperationSyncException(
          OperationSyncIssueCode.adapterUnavailable,
          'Module adapter is unavailable.',
        );
      }
      await adapter.applyForTesting(section.records);
    }
    state = await _move(
      state,
      state.copyWith(
        phase: OperationSyncPhase.verifying,
        checkpoint: _checkpointFor(package, 'verifying'),
        updatedAt: _clock().toUtc(),
      ),
    );
    for (final section in package.sections) {
      final verified = await validator.registry
          .adapterFor(section.module)!
          .verifyForTesting(section.records);
      if (!verified) {
        await _fail(
          state,
          OperationSyncIssueCode.integrityFailure,
          'fixtureReadBackMismatch',
        );
        throw const OperationSyncException(
          OperationSyncIssueCode.integrityFailure,
          'Fixture read-back verification failed.',
        );
      }
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
    await historyRepository.create(
      OperationSyncHistory(
        operationId: completed.operationId!,
        packageId: package.packageId,
        packageDigest: package.packageDigest,
        sourceType: package.sourceType.stableId,
        transferMode: package.transferMode.stableId,
        startedAt: completed.startedAt!,
        completedAt: completedAt,
        moduleIds: [for (final section in package.sections) section.module],
        recordCount: preview.recordCount,
        createCount: preview.createCount,
        noChangeCount: preview.noChangeCount,
        conflictCount: preview.conflictCount,
        quarantineCount: 0,
        result: OperationSyncHistoryResult.success,
        isRecoveryExecution: false,
      ),
    );
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
