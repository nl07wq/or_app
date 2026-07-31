import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';
import 'package:or_app/features/operation_date/repository/indexed_db_operation_state_repository.dart';
import 'package:or_app/features/operation_date/repository/operation_state_repository.dart';
import 'package:or_app/features/operation_date/services/operation_date_service.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

Future<OperationDateService> operationDateServiceFor(
  String localDate, {
  FakeIndexedDbDatabase? database,
}) async {
  final repository = IndexedDbOperationStateRepository(
    database ?? FakeIndexedDbDatabase(),
  );
  await repository.createInitial(OperationLocalDate.parse(localDate));
  return OperationDateService(repository);
}

void seedOperationState(FakeIndexedDbDatabase database, String localDate) {
  final timestamp = DateTime.utc(2026, 7, 31, 12);
  final state = OperationState(
    operationDate: OperationLocalDate.parse(localDate),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
  database.seed(
    'operation_state',
    OperationState.canonicalId,
    state.toRecord(),
  );
}

OperationState operationStateForTest(String localDate) {
  final timestamp = DateTime.utc(2026, 7, 31, 12);
  return OperationState(
    operationDate: OperationLocalDate.parse(localDate),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

OperationDateService operationDateServiceFromFuture(
  Future<OperationState> state,
) => OperationDateService(_FutureOperationStateRepository(state));

class _FutureOperationStateRepository implements OperationStateRepository {
  final Future<OperationState> state;

  const _FutureOperationStateRepository(this.state);

  @override
  Future<OperationState> requireCurrent() => state;

  @override
  Future<OperationState?> findCurrent() async => state;

  @override
  Future<OperationState> validateCurrent() => state;

  @override
  Future<OperationState> createInitial(OperationLocalDate operationDate) =>
      throw UnimplementedError();

  @override
  Future<OperationState> save(
    OperationState state, {
    required int expectedRevision,
  }) => throw UnimplementedError();

  @override
  Future<OperationState> compareAndSaveRevision(
    OperationState state, {
    required int expectedRevision,
  }) => throw UnimplementedError();
}
