import 'dart:convert';

import '../../operation_sync/services/operation_transfer_canonical_service.dart';

abstract final class ReportSyncCanonicalService {
  static Object? canonicalize(Object? value) =>
      OperationTransferCanonicalService.canonicalize(value);

  static String encode(Object? value) => jsonEncode(canonicalize(value));

  static String digest(Object? value) =>
      OperationTransferCanonicalService.sha256Hex(utf8.encode(encode(value)));

  static bool isDigest(Object? value) =>
      value is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
}
