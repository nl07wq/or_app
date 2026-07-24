import '../../../core/models/morning_data.dart';
import '../../../core/models/training_session.dart';
import '../models/repository_snapshot.dart';
import '../models/repository_update_plan.dart';

class SnapshotImportAdapter {
  SnapshotImportAdapter._();

  static RepositoryUpdatePlan? createPlan(RepositorySnapshot snapshot) {
    if (!_isCompatible(snapshot)) return null;

    final targets = <RepositoryTarget>[];
    final records = <RepositoryTarget, List<Map<String, Object?>>>{};
    final training = snapshot.trainingRecords;
    final morningFact = snapshot.morningFactRecords;

    if (training != null) {
      targets.add(RepositoryTarget.training);
      records[RepositoryTarget.training] = training;
    }
    if (morningFact != null) {
      targets.add(RepositoryTarget.morningFact);
      records[RepositoryTarget.morningFact] = morningFact;
    }

    return RepositoryUpdatePlan(
      targetRepositories: targets,
      records: records,
      operationType: RepositoryOperationType.restore,
    );
  }

  static bool _isCompatible(RepositorySnapshot snapshot) {
    try {
      for (final record in snapshot.trainingRecords ?? const []) {
        TrainingSession.fromJson(Map<String, dynamic>.from(record));
      }
      for (final record in snapshot.morningFactRecords ?? const []) {
        MorningData.fromJson(Map<String, dynamic>.from(record));
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
