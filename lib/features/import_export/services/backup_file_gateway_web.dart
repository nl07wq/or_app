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
    StreamSubscription<html.Event>? onFocusSubscription;
    Timer? fallbackTimer;
    bool disposed = false;

    void disposeState() {
      if (disposed) return;
      disposed = true;

      onFocusSubscription?.cancel();
      onFocusSubscription = null;

      fallbackTimer?.cancel();
      fallbackTimer = null;

      input.remove();
    }

    void completeNullIfNeeded() {
      if (completer.isCompleted) return;
      completer.complete(null);
      disposeState();
    }

    void completeSelected(html.File file, Uint8List bytes) {
      if (completer.isCompleted) return;
      completer.complete(BackupSelectedFile(name: file.name, bytes: bytes));
      disposeState();
    }

    void completeReadError(Object error) {
      if (completer.isCompleted) return;
      completer.completeError(error);
      disposeState();
    }

    void tryCompleteNullFallback() {
      if (completer.isCompleted) return;
      if (input.files == null || input.files!.isEmpty) {
        completeNullIfNeeded();
      }
    }

    onFocusSubscription = html.window.onFocus.listen((_) {
      if (fallbackTimer != null || completer.isCompleted) {
        return;
      }
      fallbackTimer = Timer(const Duration(seconds: 1), () {
        fallbackTimer = null;
        tryCompleteNullFallback();
      });
    });

    input.onChange.first
        .then((_) {
          fallbackTimer?.cancel();
          fallbackTimer = null;
          final files = input.files;
          if (files == null || files.isEmpty) {
            completeNullIfNeeded();
            return;
          }
          final file = files.single;
          final reader = html.FileReader();
          reader.onLoad.first.then((_) {
            final result = reader.result;
            final bytes = switch (result) {
              ByteBuffer value => Uint8List.view(value),
              Uint8List value => value,
              List<int> value => Uint8List.fromList(value),
              _ => null,
            };
            if (bytes == null) {
              completeReadError(
                const FormatException(
                  'Selected file could not be read as bytes.',
                ),
              );
            } else {
              completeSelected(file, bytes);
            }
          });
          reader.onError.first.then((_) {
            completeReadError(
              reader.error ?? StateError('Backup file read failed.'),
            );
          });
          reader.readAsArrayBuffer(file);
        })
        .catchError((error, stack) {
          onFocusSubscription?.cancel();
          completeReadError(error);
        });
    input.click();
    return completer.future;
  }
}
