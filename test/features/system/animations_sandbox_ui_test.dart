import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/system/pages/animations_sandbox_page.dart';
import 'package:or_app/features/system/pages/system_page.dart';
import 'package:or_app/features/system/services/storage_status_gateway.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  setUp(() {
    AppRepositoryRegistry.install(
      AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase()),
    );
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  testWidgets('SYSTEM opens the sandbox below INITIALIZE APP DATA', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SystemPage(
          dataHealthLoader: () async => const SystemDataHealthSnapshot(
            integrity: 'READABLE',
            recoveryStatus: 'NO RECOVERY REQUIRED',
            healthStatus: 'HEALTHY',
          ),
          storageGateway: const _FakeStorageGateway(),
        ),
        routes: {
          AppRoutes.animationsSandbox: (_) => const AnimationsSandboxPage(),
          AppRoutes.bootSequencePreview: (_) => const BootSequencePreviewPage(),
        },
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(find.text('OPEN ANIMATIONS SANDBOX'), 300);

    expect(find.text('INITIALIZE APP DATA'), findsWidgets);
    expect(find.text('ANIMATIONS SANDBOX'), findsOneWidget);
    final initializeTop = tester.getTopLeft(
      find.text('INITIALIZE APP DATA').last,
    );
    final sandboxTop = tester.getTopLeft(find.text('ANIMATIONS SANDBOX'));
    expect(sandboxTop.dy, greaterThan(initializeTop.dy));

    await tester.tap(find.text('OPEN ANIMATIONS SANDBOX'));
    await tester.pumpAndSettle();
    expect(find.byType(AnimationsSandboxPage), findsOneWidget);
    expect(find.text('BOOT SEQUENCE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('boot preview controls transient timeline and all scene slots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: const AnimationsSandboxPage(),
        routes: {
          AppRoutes.bootSequencePreview: (_) => const BootSequencePreviewPage(),
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-boot-sequence-preview')));
    await tester.pumpAndSettle();

    expect(find.text('00:00 / 00:08'), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-play')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-pause')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-stop')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-replay')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('preview-play')));
    await tester.tap(find.byKey(const ValueKey('preview-play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('00:01 / 00:08'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('preview-pause')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01 / 00:08'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('preview-stop')));
    await tester.pump();
    expect(find.text('00:00 / 00:08'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('preview-scene-7')));
    await tester.tap(find.byKey(const ValueKey('preview-scene-7')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('current-scene'))).data,
      'FINAL',
    );
    for (var index = 0; index < 8; index++) {
      expect(find.byKey(ValueKey('preview-scene-$index')), findsOneWidget);
    }

    await tester.ensureVisible(find.byKey(const ValueKey('preview-replay')));
    await tester.tap(find.byKey(const ValueKey('preview-replay')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('current-scene'))).data,
      'SCENE 2',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('boot preview has no overflow at desktop width', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: BootSequencePreviewPage()));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('boot-sequence-placeholder')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeStorageGateway implements StorageStatusGateway {
  const _FakeStorageGateway();

  @override
  Future<StorageStatusSnapshot> load() async => const StorageStatusSnapshot(
    estimateState: StorageEstimateState.available,
    usageBytes: 1024,
    quotaBytes: 2048,
    persistence: StoragePersistence.persistent,
  );
}
