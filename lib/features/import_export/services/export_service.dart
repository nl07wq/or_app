import 'dart:convert';

import '../adapters/snapshot_export_adapter.dart';
import '../models/export_data.dart';
import '../models/export_metadata.dart';

class ExportService {
  ExportService._();

  static Future<ExportData> collect({
    DateTime? exportedAt,
    String? applicationVersion,
    String? devicePlatform,
  }) async {
    final snapshot = await SnapshotExportAdapter.capture();

    return ExportData.fromSnapshot(
      schemaVersion: ExportData.currentSchemaVersion,
      exportedAt: exportedAt ?? DateTime.now().toUtc(),
      snapshot: snapshot,
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
