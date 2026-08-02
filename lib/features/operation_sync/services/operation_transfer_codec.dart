import 'dart:convert';

import '../models/operation_sync_issue.dart';
import '../models/operation_transfer_package.dart';
import 'operation_transfer_canonical_service.dart';
import 'operation_transfer_decode_support.dart';
import 'operation_transfer_json_decoder.dart';

class OperationTransferCodec {
  static const maxPackageBytes = OperationTransferDecodeSupport.maxPackageBytes;
  static const maxSectionCount = OperationTransferDecodeSupport.maxSectionCount;
  static const maxRecordsPerSection =
      OperationTransferDecodeSupport.maxRecordsPerSection;
  static const maxPackageRecords =
      OperationTransferDecodeSupport.maxPackageRecords;

  const OperationTransferCodec();

  OperationTransferPackage decodeUtf8(List<int> bytes) {
    if (bytes.isEmpty) {
      throw const OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Operation Transfer input is empty.',
      );
    }
    if (bytes.length > maxPackageBytes) {
      throw const OperationSyncException(
        OperationSyncIssueCode.packageTooLarge,
        'Operation Transfer Package exceeds 32 MiB.',
      );
    }
    try {
      return decode(utf8.decode(bytes, allowMalformed: false));
    } on FormatException catch (error) {
      throw OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Operation Transfer Package is not valid UTF-8: ${error.message}',
      );
    }
  }

  OperationTransferPackage decode(String input) {
    if (input.isEmpty) {
      throw const OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Operation Transfer input is empty.',
      );
    }
    if (utf8.encode(input).length > maxPackageBytes) {
      throw const OperationSyncException(
        OperationSyncIssueCode.packageTooLarge,
        'Operation Transfer Package exceeds 32 MiB.',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(input);
    } on FormatException catch (error) {
      throw OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Operation Transfer JSON is invalid: ${error.message}',
      );
    }
    if (decoded is! Map) {
      throw const OperationSyncException(
        OperationSyncIssueCode.integrityFailure,
        'Operation Transfer root must be an object.',
      );
    }
    return OperationTransferJsonDecoder.decode(
      Map<String, Object?>.from(decoded),
    );
  }

  String encode(OperationTransferPackage package) {
    return OperationTransferCanonicalService.encode(package.toJson());
  }
}
