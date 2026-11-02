import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../../data/indexed_db/indexed_db_database.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';

/// Binary presentation assets for the BASE CAMP editor.
///
/// This store is intentionally separate from records and backup sections:
/// imported art is device-local and JSON stores only [BaseCampStoredAsset.id]
/// references. It must never participate in FINALIZE or daily backups.
@immutable
class BaseCampStoredAsset {
  const BaseCampStoredAsset({
    required this.id,
    required this.mimeType,
    required this.bytes,
  });

  static const maximumBytes = 8 * 1024 * 1024;
  static const supportedMimeTypes = <String>{
    'image/png',
    'image/gif',
    'image/jpeg',
  };

  final String id;
  final String mimeType;
  final Uint8List bytes;

  int get byteLength => bytes.lengthInBytes;

  Map<String, Object?> toRecord() => <String, Object?>{
    'id': id,
    'mimeType': mimeType,
    'byteLength': byteLength,
    // IndexedDB receives a structured-cloneable typed byte array. It is never
    // copied into SharedPreferences or Base Camp JSON.
    'bytes': Uint8List.fromList(bytes),
  };

  factory BaseCampStoredAsset.fromRecord(Map<String, Object?> record) {
    final id = record['id'];
    final mimeType = record['mimeType'];
    final declaredLength = record['byteLength'];
    final rawBytes = record['bytes'];
    final bytes = switch (rawBytes) {
      Uint8List value => Uint8List.fromList(value),
      ByteBuffer value => Uint8List.view(value),
      List value when value.every((item) => item is int) => Uint8List.fromList(
        value.cast<int>(),
      ),
      _ => null,
    };
    if (id is! String ||
        id.isEmpty ||
        mimeType is! String ||
        declaredLength is! int ||
        bytes == null ||
        declaredLength != bytes.lengthInBytes) {
      throw const FormatException('Invalid Base Camp asset record.');
    }
    return BaseCampStoredAsset(id: id, mimeType: mimeType, bytes: bytes)
      .._validate();
  }

  void _validate() {
    if (!supportedMimeTypes.contains(mimeType) ||
        bytes.isEmpty ||
        bytes.lengthInBytes > maximumBytes ||
        !_matchesSignature(mimeType, bytes)) {
      throw const FormatException('Invalid Base Camp image asset.');
    }
  }

  static bool _matchesSignature(String mimeType, Uint8List bytes) {
    if (mimeType == 'image/png') {
      return bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47 &&
          bytes[4] == 0x0d &&
          bytes[5] == 0x0a &&
          bytes[6] == 0x1a &&
          bytes[7] == 0x0a;
    }
    if (mimeType == 'image/gif') {
      return bytes.length >= 6 &&
          bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x38;
    }
    return bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
  }
}

class BaseCampAssetStorageException implements Exception {
  const BaseCampAssetStorageException(this.code);

  final String code;

  @override
  String toString() => 'BaseCampAssetStorageException($code)';
}

class BaseCampAssetStore {
  BaseCampAssetStore({Future<IndexedDbDatabase> Function()? databaseLoader})
    : _databaseLoader = databaseLoader ?? openIndexedDbDatabase;

  final Future<IndexedDbDatabase> Function() _databaseLoader;

  Future<void> save(BaseCampStoredAsset asset) async {
    try {
      asset._validate();
    } on FormatException {
      throw const BaseCampAssetStorageException('invalid_asset');
    }
    try {
      final database = await _databaseLoader();
      await database.put(IndexedDbStoreNames.baseCampAssets, asset.toRecord());
    } catch (error) {
      if (error is BaseCampAssetStorageException) rethrow;
      throw const BaseCampAssetStorageException('storage_failed');
    }
  }

  Future<BaseCampStoredAsset?> read(String assetId) async {
    try {
      final database = await _databaseLoader();
      final record = await database.findById(
        IndexedDbStoreNames.baseCampAssets,
        assetId,
      );
      return record == null ? null : BaseCampStoredAsset.fromRecord(record);
    } on FormatException {
      throw const BaseCampAssetStorageException('invalid_asset');
    } catch (error) {
      if (error is BaseCampAssetStorageException) rethrow;
      throw const BaseCampAssetStorageException('storage_failed');
    }
  }

  Future<void> delete(String assetId) async {
    try {
      final database = await _databaseLoader();
      await database.deleteById(IndexedDbStoreNames.baseCampAssets, assetId);
    } catch (_) {
      throw const BaseCampAssetStorageException('storage_failed');
    }
  }
}
