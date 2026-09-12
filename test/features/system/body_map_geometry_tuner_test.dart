import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/services/body_map_geometry_tuner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const side = 'front';
  const leftId = 'front-shoulder-left';
  const rightId = 'front-shoulder-right';
  final leftPath = Path()..addOval(const Rect.fromLTWH(55, 75, 18, 24));
  final rightPath = Path()..addOval(const Rect.fromLTWH(127, 75, 18, 24));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('creates a baseline CURRENT draft and valid paths for every preset', () {
    final controller = BodyMapGeometryTunerController(
      baselineCommit: 'baseline',
    );
    final baseline = controller.pathFor(
      side: side,
      regionId: leftId,
      basePath: leftPath,
    );
    expect(baseline.contains(const Offset(64, 87)), isTrue);
    final draft = controller.draftFor(side, leftId)!;
    expect(draft.shape, BodyMapGeometryShape.current);
    expect(draft.scaleX, 1);
    expect(draft.scaleY, 1);

    for (final shape in BodyMapGeometryShape.values) {
      controller.update(draft.copyWith(shape: shape));
      final path = controller.pathFor(
        side: side,
        regionId: leftId,
        basePath: leftPath,
      );
      expect(path.getBounds().isEmpty, isFalse, reason: shape.name);
      expect(
        path.contains(path.getBounds().center),
        isTrue,
        reason: shape.name,
      );
    }
  });

  test(
    'linked bilateral edit mirrors x and rotation while preserving size',
    () {
      final controller = BodyMapGeometryTunerController(
        baselineCommit: 'baseline',
      );
      controller
        ..pathFor(side: side, regionId: leftId, basePath: leftPath)
        ..pathFor(side: side, regionId: rightId, basePath: rightPath);
      final left = controller.draftFor(side, leftId)!;
      controller.update(
        left.copyWith(x: 70, width: 22, height: 30, rotationDeg: -20),
      );
      final right = controller.draftFor(side, rightId)!;
      expect(right.x, 130);
      expect(right.width, 22);
      expect(right.height, 30);
      expect(right.rotationDeg, 20);
    },
  );

  test(
    'reset, persistence, and deterministic copy retain only changed drafts',
    () async {
      final controller = BodyMapGeometryTunerController(
        baselineCommit: 'abc123',
      );
      controller.pathFor(side: side, regionId: leftId, basePath: leftPath);
      final changed = controller.draftFor(side, leftId)!;
      controller.update(
        changed.copyWith(shape: BodyMapGeometryShape.ellipse, x: 68),
      );
      await Future<void>.delayed(Duration.zero);

      final reloaded = BodyMapGeometryTunerController(baselineCommit: 'abc123');
      await reloaded.load();
      reloaded.pathFor(side: side, regionId: leftId, basePath: leftPath);
      final restored = reloaded.draftFor(side, leftId)!;
      expect(restored.shape, BodyMapGeometryShape.ellipse);
      expect(restored.x, 68);

      final output = reloaded.copyAllChanges({
        BodyMapGeometryTunerController.keyFor(side, leftId): leftPath
            .getBounds(),
      });
      expect(output, contains('baselineCommit: abc123'));
      expect(output, contains('regionId: $leftId'));
      expect(output, contains('shape: ELLIPSE'));
      expect(output, contains('x: 68.00'));

      reloaded.resetRegion(side, leftId);
      reloaded.pathFor(side: side, regionId: leftId, basePath: leftPath);
      final reset = reloaded.draftFor(side, leftId)!;
      expect(reloaded.isChanged(reset, leftPath.getBounds()), isFalse);
    },
  );

  test(
    'copy-all output follows the prescribed front then back region order',
    () {
      final controller = BodyMapGeometryTunerController(
        baselineCommit: 'baseline',
      );
      const glute = 'back-glutes-left';
      const calf = 'back-calves-left';
      controller
        ..pathFor(side: 'back', regionId: calf, basePath: leftPath)
        ..pathFor(side: 'back', regionId: glute, basePath: leftPath)
        ..pathFor(side: side, regionId: leftId, basePath: leftPath);
      controller
        ..update(controller.draftFor('back', calf)!.copyWith(x: 71))
        ..update(controller.draftFor('back', glute)!.copyWith(x: 72))
        ..update(controller.draftFor(side, leftId)!.copyWith(x: 73));
      final output = controller.copyAllChanges({
        BodyMapGeometryTunerController.keyFor('back', calf): leftPath
            .getBounds(),
        BodyMapGeometryTunerController.keyFor('back', glute): leftPath
            .getBounds(),
        BodyMapGeometryTunerController.keyFor(side, leftId): leftPath
            .getBounds(),
      });
      expect(output.indexOf(leftId), lessThan(output.indexOf(glute)));
      expect(output.indexOf(glute), lessThan(output.indexOf(calf)));
    },
  );

  test(
    'preserves a mismatched baseline as stale without applying it',
    () async {
      final old = BodyMapGeometryTunerController(baselineCommit: '2fb726a');
      old.pathFor(side: side, regionId: leftId, basePath: leftPath);
      old.update(old.draftFor(side, leftId)!.copyWith(x: 70));
      await Future<void>.delayed(Duration.zero);

      final baked = BodyMapGeometryTunerController(baselineCommit: 'baked-v1');
      await baked.load();
      final neutral = baked.pathFor(
        side: side,
        regionId: leftId,
        basePath: leftPath,
      );
      expect(baked.hasStaleDraft, isTrue);
      expect(neutral.contains(const Offset(64, 87)), isTrue);
      expect(baked.copyStaleDraft(), contains('draftBaselineCommit: 2fb726a'));
    },
  );

  test(
    'composite trapezius keeps two components as one visible hit region',
    () {
      final controller = BodyMapGeometryTunerController(
        baselineCommit: 'baked',
      );
      const id = 'back-trapezius';
      final diamond = Path()
        ..moveTo(100, 62)
        ..lineTo(115, 86)
        ..lineTo(100, 110)
        ..lineTo(85, 86)
        ..close();
      controller.pathFor(side: 'back', regionId: id, basePath: diamond);
      expect(
        controller.addComponent('back', id, BodyMapGeometryShape.rect),
        isTrue,
      );
      final draft = controller.draftFor('back', id)!;
      controller.updateComponent(
        'back',
        id,
        1,
        draft.effectiveComponents[1].copyWith(y: 68, width: 20),
      );
      final path = controller.pathFor(
        side: 'back',
        regionId: id,
        basePath: diamond,
      );
      expect(path.contains(const Offset(100, 86)), isTrue);
      expect(path.contains(const Offset(100, 68)), isTrue);
      final copied = controller.copyRegion(controller.draftFor('back', id)!);
      expect(copied, contains('shape: COMPOSITE'));
      expect(copied, contains('component-1'));
      expect(controller.deleteComponent('back', id, 1), isTrue);
      expect(controller.deleteComponent('back', id, 0), isFalse);
    },
  );

  test(
    'exports a locked composite region through copy-region and copy-all',
    () {
      final controller = BodyMapGeometryTunerController(
        baselineCommit: 'composite-export',
      );
      const id = 'back-trapezius';
      final diamond = Path()
        ..moveTo(100, 62)
        ..lineTo(115, 86)
        ..lineTo(100, 110)
        ..lineTo(85, 86)
        ..close();
      controller.pathFor(side: 'back', regionId: id, basePath: diamond);
      expect(
        controller.addComponent('back', id, BodyMapGeometryShape.rect),
        isTrue,
      );
      final composite = controller.draftFor('back', id)!;
      controller.update(composite.copyWith(locked: true));
      final locked = controller.draftFor('back', id)!;

      final region = controller.copyRegion(locked);
      final all = controller.copyAllChanges({
        BodyMapGeometryTunerController.keyFor('back', id): diamond.getBounds(),
      });
      for (final output in <String>[region, all]) {
        expect(output, contains('shape: COMPOSITE'));
        expect(output, contains('mirrorLinked: true'));
        expect(output, contains('componentId: component-0'));
        expect(output, contains('componentId: component-1'));
        expect(output, contains('shape: RECT'));
        expect(output, contains('locked: true'));
      }
      expect(all.split('regionId: $id').length - 1, 1);
    },
  );

  test('copy-all preserves mixed locked single and composite drafts', () {
    final controller = BodyMapGeometryTunerController(
      baselineCommit: 'mixed-export',
    );
    const singleId = 'front-shoulder-left';
    const compositeId = 'back-trapezius';
    final diamond = Path()
      ..moveTo(100, 62)
      ..lineTo(115, 86)
      ..lineTo(100, 110)
      ..lineTo(85, 86)
      ..close();
    controller
      ..pathFor(side: 'front', regionId: singleId, basePath: leftPath)
      ..pathFor(side: 'back', regionId: compositeId, basePath: diamond);
    controller.update(
      controller
          .draftFor('front', singleId)!
          .copyWith(shape: BodyMapGeometryShape.ellipse, locked: true),
    );
    expect(
      controller.addComponent(
        'back',
        compositeId,
        BodyMapGeometryShape.roundedRect,
      ),
      isTrue,
    );
    controller.update(
      controller.draftFor('back', compositeId)!.copyWith(locked: true),
    );

    final output = controller.copyAllChanges({
      BodyMapGeometryTunerController.keyFor('front', singleId): leftPath
          .getBounds(),
      BodyMapGeometryTunerController.keyFor('back', compositeId): diamond
          .getBounds(),
    });
    expect(output.indexOf(singleId), lessThan(output.indexOf(compositeId)));
    expect(output, contains('shape: ELLIPSE'));
    expect(output.split('regionId: $compositeId').length - 1, 1);
    expect(output, contains('shape: COMPOSITE'));
    expect(output, contains('shape: ROUNDED_RECT'));
  });

  test('persists composite components without changing their export', () async {
    final controller = BodyMapGeometryTunerController(
      baselineCommit: 'persist-composite',
    );
    const id = 'back-trapezius';
    final diamond = Path()
      ..moveTo(100, 62)
      ..lineTo(115, 86)
      ..lineTo(100, 110)
      ..lineTo(85, 86)
      ..close();
    controller.pathFor(side: 'back', regionId: id, basePath: diamond);
    expect(
      controller.addComponent('back', id, BodyMapGeometryShape.rect),
      isTrue,
    );
    await Future<void>.delayed(Duration.zero);

    final reloaded = BodyMapGeometryTunerController(
      baselineCommit: 'persist-composite',
    );
    await reloaded.load();
    reloaded.pathFor(side: 'back', regionId: id, basePath: diamond);
    final restored = reloaded.draftFor('back', id)!;
    expect(restored.effectiveComponents, hasLength(2));
    expect(restored.effectiveComponents[1].shape, BodyMapGeometryShape.rect);
    expect(
      reloaded.copyAllChanges({
        BodyMapGeometryTunerController.keyFor('back', id): diamond.getBounds(),
      }),
      contains('shape: COMPOSITE'),
    );
  });

  test('migrates a legacy single-shape schema to component-0', () async {
    SharedPreferences.setMockInitialValues({
      BodyMapGeometryTunerController.storageKey: jsonEncode({
        'baselineCommit': 'legacy',
        'drafts': [
          {
            'side': 'front',
            'regionId': leftId,
            'shape': 'ellipse',
            'x': 68,
            'y': 87,
            'width': 18,
            'height': 24,
            'mirrorLinked': true,
            'locked': true,
          },
        ],
      }),
    });
    final controller = BodyMapGeometryTunerController(baselineCommit: 'legacy');
    await controller.load();
    final draft = controller.draftFor(side, leftId)!;
    expect(draft.effectiveComponents, hasLength(1));
    expect(draft.effectiveComponents.single.componentId, 'component-0');
    expect(
      draft.effectiveComponents.single.shape,
      BodyMapGeometryShape.ellipse,
    );
    expect(draft.locked, isTrue);
  });

  test('loads a composite schema without losing component values', () async {
    SharedPreferences.setMockInitialValues({
      BodyMapGeometryTunerController.storageKey: jsonEncode({
        'schemaVersion': 2,
        'baselineCommit': 'composite-schema',
        'drafts': [
          {
            'side': 'back',
            'regionId': 'back-trapezius',
            'shape': 'current',
            'x': 100,
            'y': 77,
            'width': 35,
            'height': 29.5,
            'locked': true,
            'components': [
              {
                'componentId': 'component-0',
                'shape': 'current',
                'x': 100,
                'y': 77,
                'width': 35,
                'height': 29.5,
                'scaleX': 1.4,
                'scaleY': 1,
                'rotationDeg': 0,
                'cornerRadius': 0,
              },
              {
                'componentId': 'component-1',
                'shape': 'roundedRect',
                'x': 100,
                'y': 72.5,
                'width': 18,
                'height': 13.55,
                'scaleX': 1.01,
                'scaleY': 1.5,
                'rotationDeg': 0,
                'cornerRadius': 0,
              },
            ],
          },
        ],
      }),
    });
    final controller = BodyMapGeometryTunerController(
      baselineCommit: 'composite-schema',
    );
    await controller.load();
    final trapezius = controller.draftFor('back', 'back-trapezius')!;
    expect(trapezius.locked, isTrue);
    expect(trapezius.effectiveComponents, hasLength(2));
    expect(trapezius.effectiveComponents[0].scaleX, 1.4);
    expect(
      trapezius.effectiveComponents[1].shape,
      BodyMapGeometryShape.roundedRect,
    );
    expect(trapezius.effectiveComponents[1].scaleY, 1.5);
  });

  test(
    'promotes a compatible draft wrapped as stale by an app SHA change',
    () async {
      final original = {
        'baselineCommit': '58bf2859ef511e6c1ce577afc9e48b64a1de895a',
        'drafts': [
          {
            'side': 'back',
            'regionId': 'back-trapezius',
            'shape': 'current',
            'x': 100,
            'y': 77,
            'width': 35,
            'height': 29.5,
            'locked': true,
            'components': [
              {
                'componentId': 'component-0',
                'shape': 'current',
                'x': 100,
                'y': 77,
                'width': 35,
                'height': 29.5,
              },
              {
                'componentId': 'component-1',
                'shape': 'roundedRect',
                'x': 100,
                'y': 72.5,
                'width': 18,
                'height': 13.55,
                'scaleX': 1.01,
                'scaleY': 1.5,
              },
            ],
          },
        ],
      };
      SharedPreferences.setMockInitialValues({
        BodyMapGeometryTunerController.storageKey: jsonEncode({
          'schemaVersion': 2,
          'baselineCommit': 'a734cf1d0a60c82c7beb0bfbbd061d5c2267e523',
          'drafts': const [],
          'staleDraft': original,
        }),
      });
      final controller = BodyMapGeometryTunerController(
        baselineCommit:
            BodyMapGeometryTunerController.productOwnerRecoveryBaseline,
      );
      await controller.load();
      final trapezius = controller.draftFor('back', 'back-trapezius')!;
      expect(controller.hasStaleDraft, isFalse);
      expect(trapezius.effectiveComponents, hasLength(2));
      expect(controller.copyAllChanges({}), contains('shape: COMPOSITE'));
    },
  );

  test('keeps malformed current payload and exposes a valid backup', () async {
    final backup = jsonEncode({
      'schemaVersion': 2,
      'baselineCommit': 'backup',
      'drafts': [
        {
          'side': 'front',
          'regionId': leftId,
          'shape': 'current',
          'x': 64,
          'y': 87,
          'width': 18,
          'height': 24,
        },
      ],
    });
    SharedPreferences.setMockInitialValues({
      BodyMapGeometryTunerController.storageKey: '{not-json',
      BodyMapGeometryTunerController.backupStorageKey: backup,
    });
    final controller = BodyMapGeometryTunerController(baselineCommit: 'backup');
    await controller.load();
    expect(controller.loadError, isNotNull);
    expect(controller.hasRecoverableBackup, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(BodyMapGeometryTunerController.storageKey),
      '{not-json',
    );
    expect(controller.restoreBackupDraft(), isTrue);
    expect(controller.draftFor(side, leftId), isNotNull);
  });

  test(
    'load wins over startup placeholders and retains all restored drafts',
    () async {
      final saved = jsonEncode({
        'schemaVersion': 2,
        'baselineCommit': 'startup',
        'drafts': [
          {
            'side': 'front',
            'regionId': leftId,
            'shape': 'ellipse',
            'x': 70,
            'y': 87,
            'width': 18,
            'height': 24,
          },
          {
            'side': 'back',
            'regionId': 'back-trapezius',
            'shape': 'current',
            'x': 100,
            'y': 77,
            'width': 35,
            'height': 29.5,
          },
        ],
      });
      SharedPreferences.setMockInitialValues({
        BodyMapGeometryTunerController.storageKey: saved,
      });
      final controller = BodyMapGeometryTunerController(
        baselineCommit: 'startup',
      );
      final loading = controller.load();
      controller.pathFor(side: side, regionId: leftId, basePath: leftPath);
      await loading;
      expect(
        controller.draftFor(side, leftId)!.shape,
        BodyMapGeometryShape.ellipse,
      );
      expect(controller.draftFor('back', 'back-trapezius'), isNotNull);

      controller.update(controller.draftFor(side, leftId)!.copyWith(x: 72));
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      final persisted =
          jsonDecode(
                prefs.getString(BodyMapGeometryTunerController.storageKey)!,
              )
              as Map<String, dynamic>;
      expect((persisted['drafts'] as List<dynamic>), hasLength(2));
    },
  );

  test(
    'restores the product owner fixture with a locked composite trapezius',
    () async {
      final controller = BodyMapGeometryTunerController(
        baselineCommit:
            BodyMapGeometryTunerController.productOwnerRecoveryBaseline,
      );
      expect(controller.restoreProductOwnerRecoveryDraft(), isTrue);
      expect(controller.drafts, hasLength(26));
      final trapezius = controller.draftFor('back', 'back-trapezius')!;
      expect(trapezius.locked, isTrue);
      expect(trapezius.effectiveComponents, hasLength(2));
      expect(
        trapezius.effectiveComponents[0].shape,
        BodyMapGeometryShape.current,
      );
      expect(
        trapezius.effectiveComponents[1].shape,
        BodyMapGeometryShape.roundedRect,
      );
      expect(trapezius.effectiveComponents[1].height, 13.55);
      final output = controller.copyAllChanges({});
      for (final regionId in <String>[
        'front-shoulder-left',
        'front-chest-left',
        'front-core',
        'front-biceps-left',
        'front-forearm-left',
        'front-quadriceps-right',
        'back-shoulder-left',
        'back-trapezius',
        'back-lats-left',
        'back-triceps-right',
        'back-forearm-left',
        'back-glutes-left',
        'back-hamstrings-left',
        'back-calves-left',
      ]) {
        expect(output, contains('regionId: $regionId'));
      }
      expect(output, contains('shape: COMPOSITE'));
      expect(output, contains('componentId: component-1'));
      await Future<void>.delayed(Duration.zero);
      final reloaded = BodyMapGeometryTunerController(
        baselineCommit:
            BodyMapGeometryTunerController.productOwnerRecoveryBaseline,
      );
      await reloaded.load();
      expect(reloaded.drafts, hasLength(26));
      expect(
        reloaded.draftFor('back', 'back-trapezius')!.effectiveComponents,
        hasLength(2),
      );
    },
  );

  test('only an explicit reset persists an empty tuner draft', () async {
    final controller = BodyMapGeometryTunerController(baselineCommit: 'reset');
    controller.pathFor(side: side, regionId: leftId, basePath: leftPath);
    controller.update(controller.draftFor(side, leftId)!.copyWith(x: 70));
    await Future<void>.delayed(Duration.zero);
    controller.resetAll();
    await Future<void>.delayed(Duration.zero);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(BodyMapGeometryTunerController.storageKey)!;
    final payload = jsonDecode(raw) as Map<String, dynamic>;
    expect(payload['schemaVersion'], 2);
    expect(payload['drafts'], isEmpty);
  });
}
