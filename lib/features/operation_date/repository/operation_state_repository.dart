import '../models/operation_local_date.dart';
import '../models/operation_state.dart';

class OperationStateRevisionConflictException implements Exception {
  final int expectedRevision;
  final int actualRevision;

  const OperationStateRevisionConflictException({
    required this.expectedRevision,
    required this.actualRevision,
  });

  @override
  String toString() =>
      'Operation state revision conflict: expected $expectedRevision, '
      'actual $actualRevision.';
}

abstract interface class OperationStateRepository {
  Future<OperationState?> findCurrent();

  Future<OperationState> requireCurrent();

  Future<OperationState> createInitial(OperationLocalDate operationDate);

  Future<OperationState> save(
    OperationState state, {
    required int expectedRevision,
  });

  Future<OperationState> compareAndSaveRevision(
    OperationState state, {
    required int expectedRevision,
  });

  Future<OperationState> validateCurrent();
}
