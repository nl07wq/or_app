import 'repository_snapshot.dart';

enum RepositoryTarget { training, morningFact }

enum RepositoryOperationType { restore }

class RepositoryUpdatePlan {
  final List<RepositoryTarget> targetRepositories;
  final Map<RepositoryTarget, List<Map<String, Object?>>> records;
  final RepositoryOperationType operationType;

  factory RepositoryUpdatePlan({
    required Iterable<RepositoryTarget> targetRepositories,
    required Map<RepositoryTarget, List<Map<String, Object?>>> records,
    required RepositoryOperationType operationType,
  }) {
    final immutableRecords = records.map((target, targetRecords) {
      final frozenRecords = RepositorySnapshot(
        trainingRecords: targetRecords,
      ).trainingRecords!;
      return MapEntry(target, frozenRecords);
    });

    return RepositoryUpdatePlan._(
      targetRepositories: List.unmodifiable(targetRepositories),
      records: Map.unmodifiable(immutableRecords),
      operationType: operationType,
    );
  }

  const RepositoryUpdatePlan._({
    required this.targetRepositories,
    required this.records,
    required this.operationType,
  });
}
