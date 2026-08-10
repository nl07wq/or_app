// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'backup_file_gateway.dart';

BackupFileGateway createBackupFileGateway() => WebBackupFileGateway();

@JS('navigator')
external JSObject get _navigator;

@JS('File')
extension type _ShareFile._(JSObject _) implements JSObject {
  external factory _ShareFile(
    JSArray<JSAny?> bits,
    JSString fileName,
    JSObject options,
  );
}

typedef WebBackupShare =
    Future<BackupFileDelivery?> Function(String fileName, Uint8List bytes);
typedef WebBackupDownload = void Function(String fileName, Uint8List bytes);

class WebBackupFileGateway implements BackupFileGateway {
  WebBackupFileGateway({WebBackupShare? share, WebBackupDownload? download})
    : _shareOverride = share,
      _downloadOverride = download;

  final WebBackupShare? _shareOverride;
  final WebBackupDownload? _downloadOverride;

  @override
  String? get origin => html.window.location.origin;

  @override
  Future<BackupFileDelivery> shareOrSave({
    required String fileName,
    required String content,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    final shareOverride = _shareOverride;
    if (shareOverride != null) {
      final delivery = await shareOverride(fileName, bytes);
      if (delivery != null) return delivery;
    } else if (_navigator.has('share') && _navigator.has('canShare')) {
      final options = JSObject()
        ..['type'] = 'application/json;charset=utf-8'.toJS;
      final file = _ShareFile(
        <JSAny?>[bytes.toJS].toJS,
        fileName.toJS,
        options,
      );
      final shareData = JSObject()..['files'] = <JSAny?>[file].toJS;
      final canShare = _navigator
          .callMethod<JSBoolean>('canShare'.toJS, shareData)
          .toDart;
      if (canShare) {
        try {
          await _navigator
              .callMethod<JSPromise<JSAny?>>('share'.toJS, shareData)
              .toDart;
          return BackupFileDelivery.shared;
        } catch (error) {
          if (_isShareCancellation(error)) {
            return BackupFileDelivery.cancelled;
          }
          rethrow;
        }
      }
    }

    final downloadOverride = _downloadOverride;
    if (downloadOverride == null) {
      _download(fileName: fileName, bytes: bytes);
    } else {
      downloadOverride(fileName, bytes);
    }
    return BackupFileDelivery.downloaded;
  }

  static void _download({required String fileName, required Uint8List bytes}) {
    final blob = html.Blob([bytes], 'application/json;charset=utf-8');
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

  static bool _isShareCancellation(Object error) {
    if (error is html.DomException) {
      return error.name == 'AbortError';
    }
    try {
      final jsError = error as JSObject;
      if (!jsError.has('name')) return false;
      return (jsError['name'] as JSString).toDart == 'AbortError';
    } catch (_) {
      return false;
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
