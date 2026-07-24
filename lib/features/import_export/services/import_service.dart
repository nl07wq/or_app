import 'dart:convert';

import '../models/export_data.dart';
import '../models/export_metadata.dart';
import '../models/import_data.dart';
import '../models/import_result.dart';

class ImportService {
  ImportService._();

  static ImportResult importJson(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return const ImportResult.failure(
        code: ImportErrorCode.invalidJson,
        errorMessage: 'Input is not valid JSON.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      return const ImportResult.failure(
        code: ImportErrorCode.invalidStructure,
        errorMessage: 'Root JSON value must be an object.',
      );
    }

    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion is! String) {
      return const ImportResult.failure(
        code: ImportErrorCode.invalidStructure,
        errorMessage: 'schemaVersion must be a string.',
      );
    }
    if (schemaVersion != ExportData.currentSchemaVersion) {
      return ImportResult.failure(
        code: ImportErrorCode.unsupportedSchemaVersion,
        errorMessage: 'Unsupported schemaVersion: $schemaVersion.',
      );
    }

    try {
      final exportedAt = _readExportedAt(decoded);
      final training = _readRecordSection(decoded, 'training');
      final morningFact = _readRecordSection(decoded, 'morningFact');
      final metadata = _readMetadata(decoded);

      return ImportResult.success(
        ImportData(
          schemaVersion: schemaVersion,
          exportedAt: exportedAt,
          training: training,
          morningFact: morningFact,
          metadata: metadata,
        ),
      );
    } on _InvalidImportStructure catch (error) {
      return ImportResult.failure(
        code: ImportErrorCode.invalidStructure,
        errorMessage: error.message,
      );
    }
  }

  static DateTime _readExportedAt(Map<String, dynamic> decoded) {
    final value = decoded['exportedAt'];
    if (value is! String) {
      throw const _InvalidImportStructure(
        'exportedAt must be an ISO-8601 string.',
      );
    }

    final exportedAt = DateTime.tryParse(value);
    if (exportedAt == null) {
      throw const _InvalidImportStructure(
        'exportedAt must be an ISO-8601 string.',
      );
    }
    return exportedAt;
  }

  static List<Map<String, Object?>>? _readRecordSection(
    Map<String, dynamic> decoded,
    String key,
  ) {
    final value = decoded[key];
    if (value == null) return null;
    if (value is! List) {
      throw _InvalidImportStructure('$key must be an array.');
    }

    final records = <Map<String, Object?>>[];
    for (final record in value) {
      if (record is! Map<String, dynamic>) {
        throw _InvalidImportStructure('$key entries must be JSON objects.');
      }
      records.add(Map<String, Object?>.from(record));
    }
    return records;
  }

  static ExportMetadata _readMetadata(Map<String, dynamic> decoded) {
    final value = decoded['metadata'];
    if (value == null) return const ExportMetadata();
    if (value is! Map<String, dynamic>) {
      throw const _InvalidImportStructure('metadata must be a JSON object.');
    }

    final applicationVersion = value['applicationVersion'];
    if (applicationVersion != null && applicationVersion is! String) {
      throw const _InvalidImportStructure(
        'metadata.applicationVersion must be a string.',
      );
    }
    final devicePlatform = value['devicePlatform'];
    if (devicePlatform != null && devicePlatform is! String) {
      throw const _InvalidImportStructure(
        'metadata.devicePlatform must be a string.',
      );
    }

    return ExportMetadata(
      applicationVersion: applicationVersion as String?,
      devicePlatform: devicePlatform as String?,
    );
  }
}

class _InvalidImportStructure implements Exception {
  final String message;

  const _InvalidImportStructure(this.message);
}
