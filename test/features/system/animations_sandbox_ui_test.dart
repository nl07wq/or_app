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
    tester.view.physicalSize = const Size(320, 2600);
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

    expect(find.text('00:00 / 00:06'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('boot-sequence-background')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('jeep-body')), findsOneWidget);
    expect(find.byKey(const ValueKey('jeep-front-wheel')), findsOneWidget);
    expect(find.byKey(const ValueKey('jeep-rear-wheel')), findsOneWidget);
    expect(
      _assetName(tester, const ValueKey('boot-sequence-background')),
      'assets/animations/sandbox/boot_sequence/phase_01/background/'
      'base_camp_background.png',
    );
    expect(
      _assetName(tester, const ValueKey('jeep-body')),
      'assets/animations/sandbox/boot_sequence/phase_01/jeep/jeep_body.png',
    );
    expect(
      _assetName(tester, const ValueKey('jeep-front-wheel')),
      'assets/animations/sandbox/boot_sequence/phase_01/jeep/wheel.png',
    );
    expect(
      _assetName(tester, const ValueKey('jeep-rear-wheel')),
      'assets/animations/sandbox/boot_sequence/phase_01/jeep/wheel.png',
    );
    expect(find.byKey(const ValueKey('preview-play')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-pause')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-stop')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-replay')), findsOneWidget);

    final startAlignment = _jeepAlignment(tester);
    final startScale = _jeepScale(tester);
    final startWheelTurns = _frontWheelTurns(tester);

    await tester.ensureVisible(find.byKey(const ValueKey('preview-play')));
    await tester.tap(find.byKey(const ValueKey('preview-play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('00:01 / 00:06'), findsOneWidget);
    expect(_jeepAlignment(tester).x, lessThan(startAlignment.x));
    expect(_jeepAlignment(tester).y, greaterThan(startAlignment.y));
    expect(_jeepScale(tester), greaterThan(startScale));
    expect(_frontWheelTurns(tester), lessThan(startWheelTurns));
    expect(_rearWheelTurns(tester), _frontWheelTurns(tester));

    await tester.tap(find.byKey(const ValueKey('preview-pause')));
    final pausedAlignment = _jeepAlignment(tester);
    final pausedScale = _jeepScale(tester);
    final pausedWheelTurns = _frontWheelTurns(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01 / 00:06'), findsOneWidget);
    expect(_jeepAlignment(tester), pausedAlignment);
    expect(_jeepScale(tester), pausedScale);
    expect(_frontWheelTurns(tester), pausedWheelTurns);

    await tester.tap(find.byKey(const ValueKey('preview-play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_jeepScale(tester), greaterThan(pausedScale));

    await tester.tap(find.byKey(const ValueKey('preview-stop')));
    await tester.pump();
    expect(find.text('00:00 / 00:06'), findsOneWidget);
    expect(_jeepAlignment(tester), startAlignment);
    expect(_jeepScale(tester), startScale);
    expect(_frontWheelTurns(tester), startWheelTurns);

    await tester.ensureVisible(find.byKey(const ValueKey('preview-replay')));
    await tester.tap(find.byKey(const ValueKey('preview-replay')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    expect(_jeepScale(tester), greaterThan(startScale));

    await tester.ensureVisible(find.byKey(const ValueKey('preview-scene-1')));
    await tester.tap(find.byKey(const ValueKey('preview-scene-1')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('current-scene'))).data,
      'SCENE 2',
    );
    expect(
      find.byKey(const ValueKey('scene-placeholder-content')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('jeep-body')), findsNothing);
    expect(find.text('00:00 / 00:08'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('preview-scene-7')));
    await tester.tap(find.byKey(const ValueKey('preview-scene-7')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('current-scene'))).data,
      'FINAL',
    );
    expect(
      find.byKey(const ValueKey('scene-placeholder-content')),
      findsOneWidget,
    );
    for (var index = 0; index < 8; index++) {
      expect(find.byKey(ValueKey('preview-scene-$index')), findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey('preview-scene-0')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('current-scene'))).data,
      'SCENE 1',
    );
    expect(find.byKey(const ValueKey('jeep-body')), findsOneWidget);
    expect(find.text('00:00 / 00:06'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('jeep stops with both wheels after the approach interval', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: BootSequencePreviewPage()));
    await tester.ensureVisible(find.byKey(const ValueKey('preview-play')));
    await tester.tap(find.byKey(const ValueKey('preview-play')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4600));
    final stoppedAlignment = _jeepAlignment(tester);
    final stoppedScale = _jeepScale(tester);
    final stoppedWheelTurns = _frontWheelTurns(tester);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(_jeepAlignment(tester), stoppedAlignment);
    expect(_jeepScale(tester), stoppedScale);
    expect(_frontWheelTurns(tester), stoppedWheelTurns);
    expect(_rearWheelTurns(tester), stoppedWheelTurns);
    expect(find.text('00:05 / 00:06'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('boot-asset-list')),
      300,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('asset viewer lists exactly three read-only source assets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: BootSequencePreviewPage()));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('boot-asset-list')),
      300,
    );

    expect(find.byKey(const ValueKey('boot-asset-card-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('boot-asset-card-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('boot-asset-card-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('boot-asset-card-3')), findsNothing);
    expect(find.text('BACKGROUND'), findsOneWidget);
    expect(find.text('JEEP BODY'), findsOneWidget);
    expect(find.text('WHEEL'), findsOneWidget);
    expect(find.textContaining('base_camp_background.png'), findsWidgets);
    expect(find.textContaining('jeep_body.png'), findsWidgets);
    expect(find.textContaining('wheel.png'), findsWidgets);
    expect(find.text('USAGE  USED ×2'), findsOneWidget);
    expect(find.textContaining('front_wheel.png'), findsNothing);
    expect(find.textContaining('rear_wheel.png'), findsNothing);
    expect(find.text('UPLOAD'), findsNothing);
    expect(find.text('DELETE'), findsNothing);
    expect(find.text('REPLACE'), findsNothing);

    await _openAndCloseAssetPreview(
      tester,
      fileName: 'base_camp_background.png',
      assetName: 'BACKGROUND',
      path:
          'assets/animations/sandbox/boot_sequence/phase_01/background/'
          'base_camp_background.png',
      transparent: false,
    );
    await _openAndCloseAssetPreview(
      tester,
      fileName: 'jeep_body.png',
      assetName: 'JEEP BODY',
      path:
          'assets/animations/sandbox/boot_sequence/phase_01/jeep/'
          'jeep_body.png',
      transparent: true,
    );
    await _openAndCloseAssetPreview(
      tester,
      fileName: 'wheel.png',
      assetName: 'WHEEL',
      path: 'assets/animations/sandbox/boot_sequence/phase_01/jeep/wheel.png',
      transparent: true,
    );

    expect(find.byType(BootSequencePreviewPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('boot-asset-preview-dialog')),
      findsNothing,
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
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('boot-asset-list')),
      300,
    );
    expect(find.byKey(const ValueKey('boot-asset-card-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openAndCloseAssetPreview(
  WidgetTester tester, {
  required String fileName,
  required String assetName,
  required String path,
  required bool transparent,
}) async {
  final thumbnail = find.byKey(ValueKey('boot-asset-thumbnail-$fileName'));
  await tester.ensureVisible(thumbnail);
  await tester.tap(thumbnail);
  await tester.pumpAndSettle();

  final dialog = find.byKey(const ValueKey('boot-asset-preview-dialog'));
  expect(dialog, findsOneWidget);
  expect(
    find.descendant(of: dialog, matching: find.text(assetName)),
    findsWidgets,
  );
  expect(
    find.descendant(of: dialog, matching: find.text('FILE NAME  $fileName')),
    findsOneWidget,
  );
  expect(
    find.descendant(of: dialog, matching: find.text('ASSET PATH  $path')),
    findsOneWidget,
  );
  expect(
    find.byKey(ValueKey('boot-asset-preview-source-$fileName')),
    findsOneWidget,
  );
  expect(
    find.byKey(ValueKey('transparent-asset-backdrop-preview-$fileName')),
    transparent ? findsOneWidget : findsNothing,
  );

  await tester.tap(find.byKey(const ValueKey('close-boot-asset-preview')));
  await tester.pumpAndSettle();
  expect(dialog, findsNothing);
}

String _assetName(WidgetTester tester, ValueKey<String> key) =>
    (tester.widget<Image>(find.byKey(key)).image as AssetImage).assetName;

Alignment _jeepAlignment(WidgetTester tester) =>
    tester
            .widget<Align>(find.byKey(const ValueKey('jeep-assembly-position')))
            .alignment
        as Alignment;

double _jeepScale(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('jeep-assembly-scale')))
    .transform
    .entry(0, 0);

double _frontWheelTurns(WidgetTester tester) => tester
    .widget<RotationTransition>(
      find.byKey(const ValueKey('jeep-front-wheel-rotation')),
    )
    .turns
    .value;

double _rearWheelTurns(WidgetTester tester) => tester
    .widget<RotationTransition>(
      find.byKey(const ValueKey('jeep-rear-wheel-rotation')),
    )
    .turns
    .value;

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
