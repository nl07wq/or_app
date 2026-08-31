import 'dart:convert';

import '../models/backup_audit_package.dart';
import '../models/backup_package.dart';
import 'backup_canonical_codec.dart';

class BackupAuditPackageCodec {
  const BackupAuditPackageCodec();

  BackupAuditPackage decodeUtf8(List<int> bytes) {
    if (bytes.isEmpty) {
      throw const BackupException('empty_file', 'Audit Archive is empty.');
    }
    return decode(utf8.decode(bytes, allowMalformed: false));
  }

  BackupAuditPackage decode(String input) {
    final decoded = jsonDecode(input);
    if (decoded is! Map) {
      throw const BackupException(
        'invalid_root',
        'Audit Archive root must be an object.',
      );
    }
    final json = Map<String, Object?>.from(decoded);
    if (json['schema'] != BackupAuditPackage.schemaName ||
        json['schemaVersion'] != BackupAuditPackage.schemaVersion) {
      throw const BackupException(
        'unsupported_schema',
        'Audit Archive schema is not supported.',
      );
    }
    final sourceJson = _map(json, 'source');
    final source = BackupSource(
      platform: _string(sourceJson, 'platform'),
      origin: sourceJson['origin'] as String?,
      deviceLabel: sourceJson['deviceLabel'] as String?,
    );
    final rawData = _map(json, 'data');
    final digestJson = _map(json, 'digests');
    final data = <String, List<Map<String, Object?>>>{};
    final sectionDigests = <String, String>{};
    for (final section in BackupAuditSections.all) {
      final raw = rawData[section];
      if (raw is! List || raw.any((value) => value is! Map)) {
        throw BackupException(
          'missing_section',
          'Audit Archive section $section is required.',
        );
      }
      final records = [
        for (final value in raw) Map<String, Object?>.from(value as Map),
      ];
      final digest = BackupCanonicalCodec.digest(records);
      if (digestJson[section] != digest) {
        throw BackupException(
          'section_digest_mismatch',
          'Audit Archive section $section digest does not match.',
        );
      }
      data[section] = records;
      sectionDigests[section] = digest;
    }
    final exportedAt = DateTime.tryParse(_string(json, 'exportedAt'))?.toUtc();
    if (exportedAt == null) {
      throw const BackupException(
        'invalid_timestamp',
        'Audit Archive exportedAt is invalid.',
      );
    }
    final payload = {
      'schema': BackupAuditPackage.schemaName,
      'schemaVersion': BackupAuditPackage.schemaVersion,
      'archiveId': _string(json, 'archiveId'),
      'normalExportId': _string(json, 'normalExportId'),
      'normalPackageDigest': _string(json, 'normalPackageDigest'),
      'exportedAt': exportedAt.toIso8601String(),
      'source': source.toJson(),
      'archiveComplete': json['archiveComplete'],
      'digests': sectionDigests,
      'data': data,
    };
    final packageDigest = digestJson['package'];
    if (packageDigest is! String ||
        BackupCanonicalCodec.digest(payload) != packageDigest) {
      throw const BackupException(
        'package_digest_mismatch',
        'Audit Archive package digest does not match.',
      );
    }
    if (json['archiveComplete'] is! bool) {
      throw const BackupException(
        'invalid_structure',
        'Audit Archive completeness is invalid.',
      );
    }
    return BackupAuditPackage(
      archiveId: payload['archiveId']! as String,
      normalExportId: payload['normalExportId']! as String,
      normalPackageDigest: payload['normalPackageDigest']! as String,
      exportedAt: exportedAt,
      source: source,
      archiveComplete: json['archiveComplete']! as bool,
      digests: BackupDigests(package: packageDigest, sections: sectionDigests),
      data: data,
    );
  }

  static Map<String, Object?> _map(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! Map) {
      throw BackupException('invalid_structure', '$key must be an object.');
    }
    return Map<String, Object?>.from(value);
  }

  static String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw BackupException('invalid_structure', '$key must be a string.');
    }
    return value;
  }
}
