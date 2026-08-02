import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/models/profile_model.dart';
import 'package:or_app/features/system/pages/profile_page.dart';
import 'package:or_app/features/system/pages/system_page.dart';
import 'package:or_app/features/system/repository/indexed_db_profile_repository.dart';
import 'package:or_app/features/system/repository/profile_repository.dart';
import 'package:or_app/features/system/services/storage_status_gateway.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test('Storage Gateway degrades safely when the API is unavailable', () async {
    final snapshot = await StorageStatusGateway.platform().load();
    expect(snapshot.estimateState, StorageEstimateState.unsupported);
    expect(snapshot.usageBytes, isNull);
    expect(snapshot.quotaBytes, isNull);
    expect(snapshot.persistence, StoragePersistence.unknown);
  });

  testWidgets('PROFILE validates and persists all four fields', (tester) async {
    final repository = IndexedDbProfileRepository(
      FakeIndexedDbDatabase(),
      clock: () => DateTime.utc(2026, 8, 3, 12),
    );
    await tester.pumpWidget(
      MaterialApp(home: ProfilePage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('profile-user-name')),
      '  早坂  一馬  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('profile-height')),
      '175.55',
    );
    await tester.tap(find.byKey(const ValueKey('save-profile')));
    await tester.pump();
    expect(find.text('身長は小数点第一位まで入力してください。'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('profile-height')),
      '175.5',
    );
    await tester.tap(find.byKey(const ValueKey('profile-gender')));
    await tester.pumpAndSettle();
    expect(find.text('男性'), findsOneWidget);
    expect(find.text('女性'), findsOneWidget);
    expect(find.text('回答しない'), findsOneWidget);
    await tester.tap(find.text('男性').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-nationality')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('nationality-search')),
      '存在しない地域',
    );
    await tester.pump();
    expect(find.text('該当する国・地域がありません'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('nationality-search')),
      '日本',
    );
    await tester.pump();
    final japanOption = find.widgetWithText(ListTile, '日本');
    expect(japanOption, findsOneWidget);
    await tester.tap(japanOption);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-profile')));
    await tester.pumpAndSettle();

    expect(find.text('プロフィールを保存しました'), findsOneWidget);
    final stored = await repository.findCurrent();
    expect(stored!.userName, '早坂  一馬');
    expect(stored.heightCm, 175.5);
    expect(stored.gender, ProfileGender.male);
    expect(stored.nationality, '日本');

    await tester.pumpWidget(
      MaterialApp(home: ProfilePage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('日本'), findsOneWidget);
    expect(find.text('保存済み'), findsOneWidget);
  });

  testWidgets('PROFILE reports save failure without success', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfilePage(repository: _FailingProfileRepository()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-profile')));
    await tester.pumpAndSettle();
    expect(find.text('プロフィールを保存できませんでした'), findsOneWidget);
    expect(find.text('プロフィールを保存しました'), findsNothing);
  });

  for (final width in [320.0, 390.0, 900.0, 1280.0]) {
    testWidgets('PROFILE keeps a long nationality overflow-free at $width', (
      tester,
    ) async {
      final repository = IndexedDbProfileRepository(FakeIndexedDbDatabase());
      await repository.save(
        ProfileModel.validated(nationality: '英国（グレートブリテン及び北アイルランド連合王国）'),
      );
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: ProfilePage(repository: repository),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  for (final status in const [
    StorageStatusSnapshot(
      estimateState: StorageEstimateState.unsupported,
      persistence: StoragePersistence.unknown,
    ),
    StorageStatusSnapshot(
      estimateState: StorageEstimateState.failed,
      persistence: StoragePersistence.bestEffort,
    ),
  ]) {
    testWidgets('SYSTEM handles unavailable storage state without failing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: SystemPage(
            storageGateway: _FixedStorageGateway(status),
            dataHealthLoader: () async => const SystemDataHealthSnapshot(
              integrity: 'READABLE',
              recoveryStatus: 'NO RECOVERY REQUIRED',
              healthStatus: 'HEALTHY',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('IndexedDB'), findsOneWidget);
      if (status.estimateState == StorageEstimateState.unsupported) {
        expect(find.text('このブラウザでは取得できません'), findsNWidgets(2));
        expect(find.text('確認できません'), findsOneWidget);
      } else {
        expect(find.text('保存容量の取得に失敗しました'), findsNWidgets(2));
        expect(find.text('ブラウザ管理'), findsOneWidget);
      }
    });
  }
}

class _FailingProfileRepository implements ProfileRepository {
  const _FailingProfileRepository();

  @override
  Future<void> deleteCurrent() async {}

  @override
  Future<ProfileModel?> findCurrent() async => null;

  @override
  Future<ProfileModel> save(ProfileModel profile) =>
      Future.error(StateError('injected failure'));
}

class _FixedStorageGateway implements StorageStatusGateway {
  const _FixedStorageGateway(this.snapshot);

  final StorageStatusSnapshot snapshot;

  @override
  Future<StorageStatusSnapshot> load() async => snapshot;
}
