// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'backup_file_gateway.dart';

BackupFileGateway createBackupFileGateway() => _WebBackupFileGateway();

class _WebBackupFileGateway implements BackupFileGateway {
  @override
  String? get origin => html.window.location.origin;

  @override
  Future<void> save({required String fileName, required String content}) async {
    final blob = html.Blob([content], 'application/json;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    try {
      final anchor = html.AnchorElement(href: url)
        ..download = fileName
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }

  @override
  Future<BackupSelectedFile?> selectJson() {
    final completer = Completer<BackupSelectedFile?>();
    final input = html.FileUploadInputElement()
      ..accept = '.json,application/json'
      ..multiple = false
      ..style.display = 'none';
    html.document.body?.append(input);
    input.onChange.first.then((_) {
      final files = input.files;
      if (files == null || files.isEmpty) {
        if (!completer.isCompleted) completer.complete(null);
        input.remove();
        return;
      }
      final file = files.single;
      final reader = html.FileReader();
      reader.onLoad.first.then((_) {
        final result = reader.result;
        final bytes = switch (result) {
          ByteBuffer value => Uint8List.view(value),
          Uint8List value => value,
          List<int> value => value,
          _ => null,
        };
        if (bytes == null) {
          if (!completer.isCompleted) {
            completer.completeError(
              const FormatException(
                'Selected file could not be read as bytes.',
              ),
            );
          }
        } else {
          if (!completer.isCompleted) {
            completer.complete(
              BackupSelectedFile(name: file.name, bytes: bytes),
            );
          }
        }
        input.remove();
      });
      reader.onError.first.then((_) {
        if (!completer.isCompleted) {
          completer.completeError(
            reader.error ?? StateError('Backup file read failed.'),
          );
        }
        input.remove();
      });
      reader.readAsArrayBuffer(file);
    });
    input.click();
    html.window.onFocus.first.then((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!completer.isCompleted &&
          (input.files == null || input.files!.isEmpty)) {
        completer.complete(null);
        input.remove();
      }
    });
    return completer.future;
  }
}
