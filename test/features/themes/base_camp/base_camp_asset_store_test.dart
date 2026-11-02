import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/themes/base_camp/base_camp_asset_store.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_configuration.dart';

import '../../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test('stores and restores Base Camp binary assets by asset ID', () async {
    final database = FakeIndexedDbDatabase();
    final store = BaseCampAssetStore(databaseLoader: () async => database);
    final asset = BaseCampStoredAsset(
      id: 'base-camp-asset-1',
      mimeType: 'image/png',
      bytes: _pngBytes(),
    );

    await store.save(asset);
    final restored = await store.read(asset.id);

    expect(restored?.id, asset.id);
    expect(restored?.mimeType, 'image/png');
    expect(restored?.bytes, asset.bytes);
    expect(
      database.rawRecord(IndexedDbStoreNames.baseCampAssets, asset.id),
      isNotNull,
    );
  });

  test('missing assets do not alter Base Camp object metadata', () async {
    final database = FakeIndexedDbDatabase();
    final store = BaseCampAssetStore(databaseLoader: () async => database);
    const assetId = 'asset-from-another-device';
    final configuration = BaseCampMapConfiguration.defaults().copyWith(
      objects: {
        ...BaseCampMapConfiguration.defaults().objects,
        'status': BaseCampMapConfiguration.defaults().objects['status']!
            .copyWith(assetId: assetId),
      },
    );

    expect(await store.read(assetId), isNull);
    expect(configuration.objects['status']?.assetId, assetId);
    expect(configuration.toJson().toString(), isNot(contains('bytes')));
    expect(
      IndexedDbStoreNames.canonical,
      isNot(contains(IndexedDbStoreNames.baseCampAssets)),
      reason: 'Presentation assets must never become FINALIZE/backup records.',
    );
  });

  test('rejects unsupported image data without writing a record', () async {
    final database = FakeIndexedDbDatabase();
    final store = BaseCampAssetStore(databaseLoader: () async => database);
    final asset = BaseCampStoredAsset(
      id: 'invalid',
      mimeType: 'image/png',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );

    await expectLater(
      store.save(asset),
      throwsA(
        isA<BaseCampAssetStorageException>().having(
          (error) => error.code,
          'code',
          'invalid_asset',
        ),
      ),
    );
    expect(
      database.rawRecord(IndexedDbStoreNames.baseCampAssets, 'invalid'),
      isNull,
    );
  });

  test(
    'surfaces storage failures without changing the asset contract',
    () async {
      final database = FakeIndexedDbDatabase()
        ..failNextPutForStore = IndexedDbStoreNames.baseCampAssets;
      final store = BaseCampAssetStore(databaseLoader: () async => database);

      await expectLater(
        store.save(
          BaseCampStoredAsset(
            id: 'storage-failure',
            mimeType: 'image/png',
            bytes: _pngBytes(),
          ),
        ),
        throwsA(
          isA<BaseCampAssetStorageException>().having(
            (error) => error.code,
            'code',
            'storage_failed',
          ),
        ),
      );
    },
  );
}

Uint8List _pngBytes() =>
    Uint8List.fromList(<int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
