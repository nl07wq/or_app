import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/operation_sync/models/operation_transfer_package.dart';
import 'package:or_app/features/operation_sync/services/operation_transfer_canonical_service.dart';

import 'operation_transfer_test_fixture.dart';

void main() {
  test('SHA-256 matches the formal abc test vector', () {
    expect(
      OperationTransferCanonicalService.sha256Hex(utf8.encode('abc')),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('canonical JSON fixes map key order and preserves list order', () {
    expect(
      OperationTransferCanonicalService.encode({'b': 2, 'a': 1}),
      '{"a":1,"b":2}',
    );
    expect(
      OperationTransferCanonicalService.digest({'b': 2, 'a': 1}),
      OperationTransferCanonicalService.digest({'a': 1, 'b': 2}),
    );
    expect(
      OperationTransferCanonicalService.digest([1, 2]),
      isNot(OperationTransferCanonicalService.digest([2, 1])),
    );
  });

  test('canonical JSON distinguishes null and explicit zero', () {
    expect(
      OperationTransferCanonicalService.digest({'value': null}),
      isNot(OperationTransferCanonicalService.digest({'value': 0})),
    );
  });

  test('record and section digests detect payload and order changes', () {
    final first = fixtureRecord(recordId: 'a');
    final changed = fixtureRecord(
      recordId: 'a',
      canonicalPayload: const {'value': 2},
    );
    expect(first.recordDigest, isNot(changed.recordDigest));

    final ordered = fixtureSection(
      records: [
        fixtureRecord(recordId: 'a'),
        fixtureRecord(recordId: 'b'),
      ],
    );
    final reversed = fixtureSection(
      records: [
        fixtureRecord(recordId: 'b'),
        fixtureRecord(recordId: 'a'),
      ],
    );
    expect(ordered.sectionDigest, isNot(reversed.sectionDigest));
  });

  test('package digest excludes its own digest field', () {
    final package = fixturePackage();
    final changedDigest = OperationTransferPackage(
      packageId: package.packageId,
      createdAt: package.createdAt,
      sourceApplicationVersion: package.sourceApplicationVersion,
      manifest: package.manifest,
      sections: package.sections,
      packageDigest: 'f' * 64,
    );
    expect(
      OperationTransferCanonicalService.packageDigest(package),
      OperationTransferCanonicalService.packageDigest(changedDigest),
    );
  });

  test('canonical JSON rejects non-finite numbers', () {
    expect(
      () => OperationTransferCanonicalService.encode(double.nan),
      throwsFormatException,
    );
    expect(
      () => OperationTransferCanonicalService.encode(double.infinity),
      throwsFormatException,
    );
  });
}
