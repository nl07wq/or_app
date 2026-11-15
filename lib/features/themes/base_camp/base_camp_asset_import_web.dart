// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

class BaseCampImportedFile {
  const BaseCampImportedFile({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;
}

Future<BaseCampImportedFile?> platformPickBaseCampAssetFile() async {
  final file = await _pickBaseCampFile(
    accept: 'image/png,image/gif,image/jpeg',
  );
  if (file == null) return null;
  final extension = file.name.toLowerCase().split('.').last;
  final mimeType = switch (file.type.toLowerCase()) {
    'image/png' => 'image/png',
    'image/gif' => 'image/gif',
    'image/jpeg' || 'image/jpg' => 'image/jpeg',
    _ => switch (extension) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => file.type,
    },
  };
  return BaseCampImportedFile(
    name: file.name,
    mimeType: mimeType,
    bytes: file.bytes,
  );
}

Future<BaseCampImportedFile?> platformPickBaseCampWaterJsonFile() async {
  final file = await _pickBaseCampFile(accept: '.json,application/json');
  if (file == null) return null;
  return BaseCampImportedFile(
    name: file.name,
    mimeType: 'application/json',
    bytes: file.bytes,
  );
}

Future<({String name, String type, Uint8List bytes})?> _pickBaseCampFile({
  required String accept,
}) async {
  final input = html.FileUploadInputElement()..accept = accept;
  input.click();
  await input.onChange.first;
  final file = input.files?.singleOrNull;
  if (file == null) return null;
  final reader = html.FileReader();
  final completed = Completer<void>();
  reader.onLoadEnd.first.then((_) => completed.complete());
  reader.onError.first.then(
    (_) => completed.completeError(
      StateError('Base Camp asset file could not be read.'),
    ),
  );
  reader.readAsArrayBuffer(file);
  await completed.future;
  final result = reader.result;
  if (result is! ByteBuffer) {
    throw StateError('Base Camp asset file has no binary content.');
  }
  return (name: file.name, type: file.type, bytes: Uint8List.view(result));
}
