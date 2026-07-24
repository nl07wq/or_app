import 'import_data.dart';

enum ImportErrorCode { invalidJson, invalidStructure, unsupportedSchemaVersion }

class ImportResult {
  final bool success;
  final ImportData? data;
  final ImportErrorCode? errorCode;
  final String? message;

  const ImportResult.success(ImportData importedData)
    : success = true,
      data = importedData,
      errorCode = null,
      message = null;

  const ImportResult.failure({
    required ImportErrorCode code,
    required String errorMessage,
  }) : success = false,
       data = null,
       errorCode = code,
       message = errorMessage;
}
