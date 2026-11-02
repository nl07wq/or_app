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

Future<BaseCampImportedFile?> platformPickBaseCampAssetFile() =>
    Future<BaseCampImportedFile?>.error(
      UnsupportedError('Base Camp asset import is available only on the web.'),
    );
