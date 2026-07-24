import 'export_data.dart';
import 'export_metadata.dart';

class ImportData {
  final String schemaVersion;
  final DateTime exportedAt;
  final List<Map<String, Object?>>? training;
  final List<Map<String, Object?>>? morningFact;
  final ExportMetadata metadata;

  factory ImportData({
    required String schemaVersion,
    required DateTime exportedAt,
    Iterable<Map<String, Object?>>? training,
    Iterable<Map<String, Object?>>? morningFact,
    ExportMetadata metadata = const ExportMetadata(),
  }) {
    final immutableData = ExportData(
      schemaVersion: schemaVersion,
      exportedAt: exportedAt,
      training: training,
      morningFact: morningFact,
      metadata: metadata,
    );

    return ImportData._(
      schemaVersion: immutableData.schemaVersion,
      exportedAt: immutableData.exportedAt,
      training: immutableData.training,
      morningFact: immutableData.morningFact,
      metadata: immutableData.metadata,
    );
  }

  const ImportData._({
    required this.schemaVersion,
    required this.exportedAt,
    required this.training,
    required this.morningFact,
    required this.metadata,
  });
}
