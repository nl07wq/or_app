import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/operation_sync/models/operation_sync_issue.dart';
import 'package:or_app/features/operation_sync/services/operation_transfer_codec.dart';

import 'operation_transfer_test_fixture.dart';

void main() {
  const codec = OperationTransferCodec();

  test('valid formal envelope round-trips through strict JSON', () {
    final package = fixturePackage();
    final encoded = codec.encode(package);
    final decoded = codec.decode(encoded);

    expect(decoded.packageId, package.packageId);
    expect(decoded.packageDigest, package.packageDigest);
    expect(codec.encode(decoded), encoded);
  });

  test('rejects unknown and missing fields', () {
    final unknown = _json()..['unknown'] = true;
    expect(() => codec.decode(jsonEncode(unknown)), _syncError());
    final missing = _json()..remove('packageId');
    expect(() => codec.decode(jsonEncode(missing)), _syncError());
  });

  test('rejects unknown versions, source type, and transfer mode', () {
    for (final mutation in <void Function(Map<String, Object?>)>[
      (json) => json['envelopeVersion'] = 2,
      (json) => json['schemaVersion'] = '2.0',
      (json) => json['sourceType'] = 'archive',
      (json) => json['transferMode'] = 'replaceAll',
    ]) {
      final value = _json();
      mutation(value);
      expect(
        () => codec.decode(jsonEncode(value)),
        _syncError(OperationSyncIssueCode.versionUnsupported),
      );
    }
  });

  test('rejects root array, broken JSON, and trailing data', () {
    expect(() => codec.decode('[]'), _syncError());
    expect(() => codec.decode('{broken'), _syncError());
    expect(
      () => codec.decode('${codec.encode(fixturePackage())} trailing'),
      _syncError(),
    );
  });

  test('rejects numeric strings and unknown nested fields', () {
    final numeric = _json();
    _record(numeric)['recordVersion'] = '1';
    expect(
      () => codec.decode(jsonEncode(numeric)),
      _syncError(OperationSyncIssueCode.versionUnsupported),
    );
    final nested = _json();
    _record(nested)['displayLabel'] = 'not formal';
    expect(() => codec.decode(jsonEncode(nested)), _syncError());
  });

  test('rejects record, section, and package digest tampering', () {
    final record = _json();
    _record(record)['canonicalPayload'] = {'value': 999};
    expect(
      () => codec.decode(jsonEncode(record)),
      _syncError(OperationSyncIssueCode.recordDigestMismatch),
    );

    final section = _json();
    _section(section)['sectionDigest'] = 'f' * 64;
    expect(
      () => codec.decode(jsonEncode(section)),
      _syncError(OperationSyncIssueCode.sectionDigestMismatch),
    );

    final package = _json()..['packageDigest'] = 'f' * 64;
    expect(
      () => codec.decode(jsonEncode(package)),
      _syncError(OperationSyncIssueCode.packageDigestMismatch),
    );
  });

  test('rejects package, section, and record limits before apply', () {
    expect(
      () => codec.decodeUtf8(
        List<int>.filled(OperationTransferCodec.maxPackageBytes + 1, 0),
      ),
      _syncError(OperationSyncIssueCode.packageTooLarge),
    );

    final sections = _json();
    sections['sections'] = [
      for (
        var index = 0;
        index < OperationTransferCodec.maxSectionCount + 1;
        index++
      )
        fixtureSection(module: 'fixture-$index').toJson(),
    ];
    expect(
      () => codec.decode(jsonEncode(sections)),
      _syncError(OperationSyncIssueCode.recordLimitExceeded),
    );

    final records = _json();
    _section(records)['records'] = List<Object?>.filled(
      OperationTransferCodec.maxRecordsPerSection + 1,
      const {},
    );
    expect(
      () => codec.decode(jsonEncode(records)),
      _syncError(OperationSyncIssueCode.recordLimitExceeded),
    );

    final packageRecords = _json();
    final template = _section(packageRecords);
    packageRecords['sections'] = [
      for (var index = 0; index < 3; index++)
        {
          ...template,
          'module': 'fixture-$index',
          'records': List<Object?>.filled(40000, const {}),
        },
    ];
    expect(
      () => codec.decode(jsonEncode(packageRecords)),
      _syncError(OperationSyncIssueCode.recordLimitExceeded),
    );
  });
}

Map<String, Object?> _json() => Map<String, Object?>.from(
  jsonDecode(jsonEncode(fixturePackage().toJson())) as Map,
);

Map<String, Object?> _section(Map<String, Object?> package) {
  return Map<String, Object?>.from((package['sections'] as List).first as Map)
    ..also((value) => (package['sections'] as List)[0] = value);
}

Map<String, Object?> _record(Map<String, Object?> package) {
  final section = _section(package);
  final record = Map<String, Object?>.from(
    (section['records'] as List).first as Map,
  );
  (section['records'] as List)[0] = record;
  return record;
}

Matcher _syncError([OperationSyncIssueCode? code]) {
  var matcher = isA<OperationSyncException>();
  if (code != null) {
    matcher = matcher.having((error) => error.code, 'code', code);
  }
  return throwsA(matcher);
}

extension<T> on T {
  T also(void Function(T value) action) {
    action(this);
    return this;
  }
}
