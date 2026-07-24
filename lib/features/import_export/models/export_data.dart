import 'export_metadata.dart';
import 'repository_snapshot.dart';

class ExportData {
  static const currentSchemaVersion = '1.0';

  final String schemaVersion;
  final DateTime exportedAt;
  final RepositorySnapshot snapshot;
  final ExportMetadata metadata;

  factory ExportData({
    required String schemaVersion,
    required DateTime exportedAt,
    Iterable<Map<String, Object?>>? training,
    Iterable<Map<String, Object?>>? morningFact,
    ExportMetadata metadata = const ExportMetadata(),
  }) {
    return ExportData.fromSnapshot(
      schemaVersion: schemaVersion,
      exportedAt: exportedAt,
      snapshot: RepositorySnapshot(
        trainingRecords: training,
        morningFactRecords: morningFact,
      ),
      metadata: metadata,
    );
  }

  const ExportData.fromSnapshot({
    required this.schemaVersion,
    required this.exportedAt,
    required this.snapshot,
    this.metadata = const ExportMetadata(),
  });

  List<Map<String, Object?>>? get training => snapshot.trainingRecords;

  List<Map<String, Object?>>? get morningFact => snapshot.morningFactRecords;

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      if (training != null) 'training': training,
      if (morningFact != null) 'morningFact': morningFact,
      'metadata': metadata.toJson(),
    };
  }
}
