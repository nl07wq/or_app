import '../../../core/repositories/morning_repository.dart';
import '../../../core/repositories/training_repository.dart';
import '../models/repository_snapshot.dart';

class SnapshotExportAdapter {
  SnapshotExportAdapter._();

  static Future<RepositorySnapshot> capture() async {
    final trainingFuture = TrainingRepository.getAll();
    final morningFactFuture = MorningRepository.getAll();
    final training = await trainingFuture;
    final morningFact = await morningFactFuture;

    return RepositorySnapshot(
      trainingRecords: training.isEmpty
          ? null
          : training.map(
              (session) => Map<String, Object?>.from(session.toJson()),
            ),
      morningFactRecords: morningFact.isEmpty
          ? null
          : morningFact.map(
              (record) => Map<String, Object?>.from(record.toJson()),
            ),
    );
  }
}
