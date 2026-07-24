import 'export_metadata.dart';
import 'repository_snapshot.dart';

class ImportData {
  final String schemaVersion;
  final DateTime exportedAt;
  final RepositorySnapshot snapshot;
  final ExportMetadata metadata;

  factory ImportData({
    required String schemaVersion,
    required DateTime exportedAt,
    Iterable<Map<String, Object?>>? training,
    Iterable<Map<String, Object?>>? morningFact,
    ExportMetadata metadata = const ExportMetadata(),
  }) {
    return ImportData.fromSnapshot(
      schemaVersion: schemaVersion,
      exportedAt: exportedAt,
      snapshot: RepositorySnapshot(
        trainingRecords: training,
        morningFactRecords: morningFact,
      ),
      metadata: metadata,
    );
  }

  const ImportData.fromSnapshot({
    required this.schemaVersion,
    required this.exportedAt,
    required this.snapshot,
    this.metadata = const ExportMetadata(),
  });

  List<Map<String, Object?>>? get training => snapshot.trainingRecords;

  List<Map<String, Object?>>? get morningFact => snapshot.morningFactRecords;
}
