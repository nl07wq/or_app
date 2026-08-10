@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/import_export/services/backup_file_gateway.dart';
import 'package:or_app/features/import_export/services/backup_file_gateway_web.dart';

void main() {
  test('uses file share without starting a download', () async {
    var shared = false;
    var downloaded = false;
    final gateway = WebBackupFileGateway(
      share: (fileName, bytes) async {
        shared = true;
        expect(fileName, 'operation_reboot_backup.json');
        expect(utf8.decode(bytes), '{"schemaVersion":2}');
        return BackupFileDelivery.shared;
      },
      download: (_, _) => downloaded = true,
    );

    final result = await gateway.shareOrSave(
      fileName: 'operation_reboot_backup.json',
      content: '{"schemaVersion":2}',
    );

    expect(result, BackupFileDelivery.shared);
    expect(shared, isTrue);
    expect(downloaded, isFalse);
  });

  test('returns a neutral cancellation without download fallback', () async {
    var downloaded = false;
    final gateway = WebBackupFileGateway(
      share: (_, _) async => BackupFileDelivery.cancelled,
      download: (_, _) => downloaded = true,
    );

    expect(
      await gateway.shareOrSave(fileName: 'backup.json', content: '{}'),
      BackupFileDelivery.cancelled,
    );
    expect(downloaded, isFalse);
  });

  test('propagates share failure without claiming a download', () async {
    var downloaded = false;
    final gateway = WebBackupFileGateway(
      share: (_, _) async => throw StateError('share failed'),
      download: (_, _) => downloaded = true,
    );

    await expectLater(
      gateway.shareOrSave(fileName: 'backup.json', content: '{}'),
      throwsStateError,
    );
    expect(downloaded, isFalse);
  });

  test('falls back to a UTF-8 download with the requested file name', () async {
    String? downloadedName;
    Uint8List? downloadedBytes;
    final gateway = WebBackupFileGateway(
      share: (_, _) async => null,
      download: (fileName, bytes) {
        downloadedName = fileName;
        downloadedBytes = bytes;
      },
    );

    final result = await gateway.shareOrSave(
      fileName: 'operation_reboot_backup.json',
      content: '{"memo":"日本語"}',
    );

    expect(result, BackupFileDelivery.downloaded);
    expect(downloadedName, 'operation_reboot_backup.json');
    expect(utf8.decode(downloadedBytes!), '{"memo":"日本語"}');
  });
}
