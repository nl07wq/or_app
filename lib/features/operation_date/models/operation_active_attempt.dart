import 'operation_local_date.dart';

class OperationActiveAttempt {
  final String idempotencyKey;
  final OperationLocalDate targetLocalDate;
  final DateTime startedAt;
  final String? confirmationId;
  final String? confirmationDigest;
  final String? backupPackageDigest;
  final DateTime? backupGeneratedAt;
  final String? failureCode;

  OperationActiveAttempt({
    required this.idempotencyKey,
    required this.targetLocalDate,
    required this.startedAt,
    this.confirmationId,
    this.confirmationDigest,
    this.backupPackageDigest,
    this.backupGeneratedAt,
    this.failureCode,
  }) {
    if (idempotencyKey.isEmpty || !startedAt.isUtc) {
      throw const FormatException('Invalid operation active attempt.');
    }
    _validateOptionalString(confirmationId);
    _validateOptionalString(confirmationDigest);
    _validateOptionalString(backupPackageDigest);
    _validateOptionalString(failureCode);
    if (backupGeneratedAt != null && !backupGeneratedAt!.isUtc) {
      throw const FormatException('Invalid backup generated timestamp.');
    }
    if ((backupPackageDigest == null) != (backupGeneratedAt == null)) {
      throw const FormatException('Incomplete backup verification data.');
    }
  }

  Map<String, Object?> toJson() => {
    'idempotencyKey': idempotencyKey,
    'targetLocalDate': targetLocalDate.value,
    'startedAt': startedAt.toIso8601String(),
    'confirmationId': confirmationId,
    'confirmationDigest': confirmationDigest,
    'backupPackageDigest': backupPackageDigest,
    'backupGeneratedAt': backupGeneratedAt?.toIso8601String(),
    'failureCode': failureCode,
  };

  factory OperationActiveAttempt.fromJson(Map<String, Object?> json) {
    return OperationActiveAttempt(
      idempotencyKey: _requiredString(json, 'idempotencyKey'),
      targetLocalDate: OperationLocalDate.parse(
        _requiredString(json, 'targetLocalDate'),
      ),
      startedAt: _requiredUtcDate(json, 'startedAt'),
      confirmationId: _optionalString(json, 'confirmationId'),
      confirmationDigest: _optionalString(json, 'confirmationDigest'),
      backupPackageDigest: _optionalString(json, 'backupPackageDigest'),
      backupGeneratedAt: _optionalUtcDate(json, 'backupGeneratedAt'),
      failureCode: _optionalString(json, 'failureCode'),
    );
  }

  bool hasSameContent(OperationActiveAttempt other) =>
      idempotencyKey == other.idempotencyKey &&
      targetLocalDate == other.targetLocalDate &&
      startedAt == other.startedAt &&
      confirmationId == other.confirmationId &&
      confirmationDigest == other.confirmationDigest &&
      backupPackageDigest == other.backupPackageDigest &&
      backupGeneratedAt == other.backupGeneratedAt &&
      failureCode == other.failureCode;

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid operation attempt $key.');
    }
    return value;
  }

  static String? _optionalString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid operation attempt $key.');
    }
    return value;
  }

  static DateTime _requiredUtcDate(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw FormatException('Invalid operation attempt $key.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !parsed.isUtc) {
      throw FormatException('Invalid operation attempt $key.');
    }
    return parsed;
  }

  static DateTime? _optionalUtcDate(Map<String, Object?> json, String key) {
    if (json[key] == null) return null;
    return _requiredUtcDate(json, key);
  }

  static void _validateOptionalString(String? value) {
    if (value != null && value.isEmpty) {
      throw const FormatException('Invalid operation attempt value.');
    }
  }
}
