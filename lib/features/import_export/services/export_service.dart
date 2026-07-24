import 'dart:convert';

import '../../../core/repositories/morning_repository.dart';
import '../../../core/repositories/training_repository.dart';
import '../models/export_data.dart';
import '../models/export_metadata.dart';

class ExportService {
  ExportService._();

  static Future<ExportData> collect({
    DateTime? exportedAt,
    String? applicationVersion,
    String? devicePlatform,
  }) async {
    final trainingFuture = TrainingRepository.getAll();
    final morningFactFuture = MorningRepository.getAll();
    final training = await trainingFuture;
    final morningFact = await morningFactFuture;

    return ExportData(
      schemaVersion: ExportData.currentSchemaVersion,
      exportedAt: exportedAt ?? DateTime.now().toUtc(),
      training: training.isEmpty
          ? null
          : training.map(
              (session) => Map<String, Object?>.from(session.toJson()),
            ),
      morningFact: morningFact.isEmpty
          ? null
          : morningFact.map(
              (record) => Map<String, Object?>.from(record.toJson()),
            ),
      metadata: ExportMetadata(
        applicationVersion: applicationVersion,
        devicePlatform: devicePlatform,
      ),
    );
  }

  static Future<String> exportJson({
    DateTime? exportedAt,
    String? applicationVersion,
    String? devicePlatform,
  }) async {
    final data = await collect(
      exportedAt: exportedAt,
      applicationVersion: applicationVersion,
      devicePlatform: devicePlatform,
    );

    return jsonEncode(data.toJson());
  }
}
