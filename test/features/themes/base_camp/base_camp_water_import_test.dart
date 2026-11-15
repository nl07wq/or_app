import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/themes/base_camp/base_camp_asset_import.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_configuration.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_editor_page.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_map.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_water_surface_v3b.dart';
import 'package:or_app/features/operation_sync/services/operation_transfer_canonical_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fixturePath = 'test/fixtures/base_camp/OR_APP_WATER_MASK_IMPORT.json';

void main() {
  late String approvedJson;
  late Uint8List approvedBytes;

  setUpAll(() async {
    approvedBytes = await File(_fixturePath).readAsBytes();
    approvedJson = utf8.decode(approvedBytes);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('approved WATER JSON preserves every supplied coordinate', () {
    expect(
      OperationTransferCanonicalService.sha256Hex(approvedBytes),
      BaseCampMapConfigurationController.approvedWaterGeometrySha256,
    );
    final imported = BaseCampWaterGeometryImport.parse(approvedJson);
    final source = jsonDecode(approvedJson) as Map<String, dynamic>;
    final sourceAreas =
        ((source['waterFx'] as Map<String, dynamic>)['water']
                as Map<String, dynamic>)['areas']
            as List<dynamic>;

    expect(imported.areas, hasLength(4));
    expect(
      imported.areas.map((area) => area.exclusionMasks.length).toList(),
      <int>[3, 0, 2, 2],
    );
    expect(imported.exclusionCount, 7);

    for (var areaIndex = 0; areaIndex < imported.areas.length; areaIndex++) {
      final importedArea = imported.areas[areaIndex];
      final sourceArea = sourceAreas[areaIndex] as Map<String, dynamic>;
      _expectPointsMatch(importedArea.mask, sourceArea['mask'] as List);
      _expectPointsMatch(
        importedArea.shoreline,
        sourceArea['shoreline'] as List,
      );
      final sourceExclusions = sourceArea['exclusionMasks'] as List;
      expect(importedArea.exclusionMasks, hasLength(sourceExclusions.length));
      for (
        var exclusionIndex = 0;
        exclusionIndex < sourceExclusions.length;
        exclusionIndex++
      ) {
        _expectPointsMatch(
          importedArea.exclusionMasks[exclusionIndex],
          sourceExclusions[exclusionIndex] as List,
        );
      }
    }

    const removedWatchtowerPentagon = <Offset>[
      Offset(48, 246),
      Offset(126, 244),
      Offset(151, 332),
      Offset(89, 388),
      Offset(38, 344),
    ];
    expect(
      imported.areas.first.exclusionMasks.any(
        (polygon) => listEquals(polygon, removedWatchtowerPentagon),
      ),
      isFalse,
    );
  });

  test(
    'approved WATER correction asset is bundled with the exact hash',
    () async {
      final bundled = await rootBundle.load(
        BaseCampMapConfigurationController.approvedWaterGeometryAsset,
      );
      final bytes = bundled.buffer.asUint8List(
        bundled.offsetInBytes,
        bundled.lengthInBytes,
      );
      expect(
        OperationTransferCanonicalService.sha256Hex(bytes),
        BaseCampMapConfigurationController.approvedWaterGeometrySha256,
      );
    },
  );

  test(
    'one-time correction backs up and replaces WATER geometry only',
    () async {
      final original = BaseCampMapConfiguration.defaults().copyWith(
        soldierScale: .5,
        foodSmokeOrigin: const Offset(.41, .37),
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        BaseCampMapConfigurationController.storageKey,
        original.encode(),
      );
      final controller = BaseCampMapConfigurationController(
        approvedWaterGeometryLoader: () async => approvedJson,
      );

      await controller.load();

      final corrected = controller.value;
      expect(corrected.soldierScale, original.soldierScale);
      expect(corrected.foodSmokeOrigin, original.foodSmokeOrigin);
      expect(corrected.routes, original.routes);
      expect(corrected.objects.keys, original.objects.keys);
      expect(
        corrected.waterFx['water']!.effectiveAreas
            .map((area) => area.mask.length)
            .toList(),
        <int>[18, 12, 18, 35],
      );
      expect(
        corrected.waterFx['water']!.effectiveAreas
            .map((area) => area.exclusionMasks.length)
            .toList(),
        <int>[3, 0, 2, 2],
      );
      expect(
        preferences.getString(
          BaseCampMapConfigurationController.approvedWaterGeometryBackupKey,
        ),
        original.encode(),
      );
      expect(
        preferences.getInt(
          BaseCampMapConfigurationController
              .approvedWaterGeometryCorrectionMarkerKey,
        ),
        BaseCampMapConfigurationController
            .approvedWaterGeometryCorrectionVersion,
      );
      expect(
        BaseCampMapConfiguration.tryParse(
          jsonDecode(
            preferences.getString(
              BaseCampMapConfigurationController.storageKey,
            )!,
          ),
        )?.encode(),
        corrected.encode(),
      );
    },
  );

  test('correction is idempotent and preserves later WATER edits', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      BaseCampMapConfigurationController.storageKey,
      BaseCampMapConfiguration.defaults().encode(),
    );
    final first = BaseCampMapConfigurationController(
      approvedWaterGeometryLoader: () async => approvedJson,
    );
    await first.load();
    final corrected = first.value;
    final water = corrected.waterFx['water']!;
    final originalArea = water.effectiveAreas.first;
    final manuallyEditedArea = BaseCampWaterArea(
      mask: <Offset>[
        ...water.effectiveAreas.first.mask.take(17),
        const Offset(1, 491),
      ],
      shoreline: originalArea.shoreline,
      exclusionMasks: originalArea.exclusionMasks,
    );
    final editedWater = water.copyWith(
      areas: <BaseCampWaterArea>[
        manuallyEditedArea,
        ...water.effectiveAreas.skip(1),
      ],
      mask: manuallyEditedArea.mask,
    );
    final edited = corrected.copyWith(
      waterFx: <String, BaseCampWaterFx>{'water': editedWater},
    );
    await first.save(edited);

    final second = BaseCampMapConfigurationController(
      approvedWaterGeometryLoader: () async => throw StateError(
        'marker should prevent a second correction asset load',
      ),
    );
    await second.load();

    expect(second.value.encode(), edited.encode());
    expect(
      second.value.waterFx['water']!.effectiveAreas.first.mask.last,
      const Offset(1, 491),
    );
  });

  test('explicit RESET retains the approved WATER geometry', () async {
    final controller = BaseCampMapConfigurationController(
      approvedWaterGeometryLoader: () async => approvedJson,
    );
    await controller.load();
    final water = controller.value.waterFx['water']!;
    final firstArea = water.effectiveAreas.first;
    final editedArea = BaseCampWaterArea(
      mask: <Offset>[...firstArea.mask.take(17), const Offset(1, 491)],
      shoreline: firstArea.shoreline,
      exclusionMasks: firstArea.exclusionMasks,
    );
    await controller.save(
      controller.value.copyWith(
        waterFx: <String, BaseCampWaterFx>{
          'water': water.copyWith(
            areas: <BaseCampWaterArea>[
              editedArea,
              ...water.effectiveAreas.skip(1),
            ],
            mask: editedArea.mask,
          ),
        },
      ),
    );

    await controller.resetToDefaults();

    final resetAreas = controller.value.waterFx['water']!.effectiveAreas;
    expect(resetAreas.map((area) => area.mask.length), <int>[18, 12, 18, 35]);
    expect(resetAreas.map((area) => area.exclusionMasks.length), <int>[
      3,
      0,
      2,
      2,
    ]);
    expect(resetAreas.first.mask.last, isNot(const Offset(1, 491)));
  });

  test('failed correction keeps primary data and marker untouched', () async {
    final original = BaseCampMapConfiguration.defaults().copyWith(
      soldierScale: .5,
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      BaseCampMapConfigurationController.storageKey,
      original.encode(),
    );
    final controller = BaseCampMapConfigurationController(
      approvedWaterGeometryLoader: () async => approvedJson,
      storageWriter: (preferences, key, value) async {
        if (key == BaseCampMapConfigurationController.storageKey) return false;
        return preferences.setString(key, value);
      },
    );

    await controller.load();

    expect(
      preferences.getString(BaseCampMapConfigurationController.storageKey),
      original.encode(),
    );
    expect(
      preferences.containsKey(
        BaseCampMapConfigurationController
            .approvedWaterGeometryCorrectionMarkerKey,
      ),
      isFalse,
    );
    expect(
      preferences.getString(
        BaseCampMapConfigurationController.approvedWaterGeometryBackupKey,
      ),
      original.encode(),
    );
  });

  test('newer correction marker preserves existing configuration', () async {
    final original = BaseCampMapConfiguration.defaults().copyWith(
      soldierScale: .5,
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      BaseCampMapConfigurationController.storageKey,
      original.encode(),
    );
    await preferences.setInt(
      BaseCampMapConfigurationController
          .approvedWaterGeometryCorrectionMarkerKey,
      BaseCampMapConfigurationController
              .approvedWaterGeometryCorrectionVersion +
          1,
    );
    final controller = BaseCampMapConfigurationController(
      approvedWaterGeometryLoader: () async =>
          throw StateError('newer marker must prevent correction'),
    );

    await controller.load();

    expect(controller.value.encode(), original.encode());
    expect(
      preferences.getString(BaseCampMapConfigurationController.storageKey),
      original.encode(),
    );
  });

  test('WATER import replaces geometry only and round-trips schema v8', () {
    final original = BaseCampMapConfiguration.defaults();
    final originalWater = original.waterFx['water']!.copyWith(
      opacity: .73,
      speed: 2.4,
      visible: false,
    );
    final current = original.copyWith(
      soldierScale: .5,
      waterFx: <String, BaseCampWaterFx>{'water': originalWater},
    );
    final imported = BaseCampWaterGeometryImport.parse(approvedJson);
    final nextWater = imported.applyTo(originalWater);
    final next = current.copyWith(
      waterFx: <String, BaseCampWaterFx>{
        ...current.waterFx,
        'water': nextWater,
      },
    );

    expect(next.routes, same(current.routes));
    expect(next.facilityOutlines, same(current.facilityOutlines));
    expect(next.objects, same(current.objects));
    expect(next.labels, same(current.labels));
    expect(next.staticSoldiers, same(current.staticSoldiers));
    expect(next.soldierScale, .5);
    expect(nextWater.opacity, .73);
    expect(nextWater.speed, 2.4);
    expect(nextWater.visible, isFalse);
    expect(nextWater.effectiveAreas, hasLength(4));
    expect(nextWater.mask, orderedEquals(nextWater.effectiveAreas.first.mask));
    expect(
      nextWater.shoreline,
      orderedEquals(nextWater.effectiveAreas.first.shoreline),
    );
    expect(nextWater.exclusionMasks, hasLength(3));

    final restored = BaseCampMapConfiguration.tryParse(next.toJson());
    expect(restored, isNotNull);
    expect(
      restored!.waterFx['water']!.effectiveAreas
          .map((area) => area.exclusionMasks.length)
          .toList(),
      <int>[3, 0, 2, 2],
    );
    expect(restored.routes, current.routes);
    expect(restored.objects.keys, current.objects.keys);
  });

  test('approved geometry clips all WATER areas and seven exclusions', () {
    final imported = BaseCampWaterGeometryImport.parse(approvedJson);
    final water = imported.applyTo(
      BaseCampMapConfiguration.defaults().waterFx['water']!,
    );
    final effective = BaseCampWaterMaskClipper(
      water: water,
      imageRect: Offset.zero & baseCampMapArtworkSize,
      artworkSize: baseCampMapArtworkSize,
    ).getClip(baseCampMapArtworkSize);

    var exclusionsChecked = 0;
    for (
      var areaIndex = 0;
      areaIndex < water.effectiveAreas.length;
      areaIndex++
    ) {
      final area = water.effectiveAreas[areaIndex];
      final maskPath = Path()..addPolygon(area.mask, true);
      final exclusionPaths = <Path>[
        for (final polygon in area.exclusionMasks)
          Path()..addPolygon(polygon, true),
      ];
      final waterPoint = _findInteriorPoint(
        maskPath,
        rejectedBy: exclusionPaths,
      );
      expect(waterPoint, isNotNull);
      expect(effective.contains(waterPoint!), isTrue);
      for (
        var exclusionIndex = 0;
        exclusionIndex < exclusionPaths.length;
        exclusionIndex++
      ) {
        final exclusionPath = exclusionPaths[exclusionIndex];
        final excludedPoint = _findInteriorPoint(
          exclusionPath,
          rejectedBy: <Path>[
            for (var index = 0; index < exclusionPaths.length; index++)
              if (index != exclusionIndex) exclusionPaths[index],
          ],
        );
        expect(
          excludedPoint,
          isNotNull,
          reason: 'area $areaIndex exclusion $exclusionIndex',
        );
        expect(
          effective.contains(excludedPoint!),
          isFalse,
          reason: 'area $areaIndex exclusion $exclusionIndex',
        );
        exclusionsChecked++;
      }
    }
    expect(exclusionsChecked, 7);
  });

  test('invalid WATER imports fail without producing replacement data', () {
    final original = BaseCampMapConfiguration.defaults();
    final originalEncoded = original.encode();
    final valid = jsonDecode(approvedJson) as Map<String, dynamic>;

    expect(
      () => BaseCampWaterGeometryImport.parse('{not json'),
      throwsFormatException,
    );

    final wrongSchema = _deepCopy(valid)..['schemaVersion'] = 7;
    expect(
      () => BaseCampWaterGeometryImport.parse(jsonEncode(wrongSchema)),
      throwsFormatException,
    );

    final missingArea = _deepCopy(valid);
    _areas(missingArea).removeLast();
    expect(
      () => BaseCampWaterGeometryImport.parse(jsonEncode(missingArea)),
      throwsFormatException,
    );

    final wrongExclusions = _deepCopy(valid);
    (_areas(wrongExclusions)[1] as Map<String, dynamic>)['exclusionMasks'] = [
      [
        {'x': 1, 'y': 1},
        {'x': 2, 'y': 1},
        {'x': 1, 'y': 2},
      ],
    ];
    expect(
      () => BaseCampWaterGeometryImport.parse(jsonEncode(wrongExclusions)),
      throwsFormatException,
    );

    final outOfBounds = _deepCopy(valid);
    (((_areas(outOfBounds).first as Map<String, dynamic>)['mask'] as List).first
            as Map<String, dynamic>)['x'] =
        1255;
    expect(
      () => BaseCampWaterGeometryImport.parse(jsonEncode(outOfBounds)),
      throwsFormatException,
    );

    final incompatiblePrimary = _deepCopy(valid);
    ((((incompatiblePrimary['waterFx'] as Map<String, dynamic>)['water']
                        as Map<String, dynamic>)['mask']
                    as List)
                .first
            as Map<String, dynamic>)['x'] =
        1;
    expect(
      () => BaseCampWaterGeometryImport.parse(jsonEncode(incompatiblePrimary)),
      throwsFormatException,
    );
    expect(original.encode(), originalEncoded);
  });

  testWidgets('editor confirms, undoes, saves, and reloads WATER-only import', (
    tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map)['text'] as String?;
          return null;
        }
        if (call.method == 'Clipboard.getData') {
          return <String, Object?>{'text': clipboardText};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final formal = BaseCampMapConfiguration.defaults();
    final controller = BaseCampMapConfigurationController()
      ..resetForTesting(formal);
    final draftStore = BaseCampWaterDraftStore();
    var pickerCalls = 0;
    Future<BaseCampImportedFile?> picker() async {
      pickerCalls++;
      return BaseCampImportedFile(
        name: 'OR_APP_WATER_MASK_IMPORT.json',
        mimeType: 'application/json',
        bytes: approvedBytes,
      );
    }

    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: BaseCampMapEditorPage(
          configurationController: controller,
          waterDraftStore: draftStore,
          waterJsonPicker: picker,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    final importButton = find.byKey(
      const ValueKey('base-camp-editor-import-water-json'),
    );
    expect(importButton, findsOneWidget);
    await tester.tap(importButton);
    await _pumpRouteTransition(tester);
    expect(find.text('IMPORT WATER JSON?'), findsOneWidget);
    expect(find.text('WATER AREAS  4 → 4'), findsOneWidget);
    expect(find.text('EXCLUSION MASKS  5 → 7'), findsOneWidget);
    expect(controller.value.encode(), formal.encode());

    await tester.tap(find.text('CANCEL'));
    await _pumpRouteTransition(tester);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('base-camp-editor-undo')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(importButton);
    await _pumpRouteTransition(tester);
    await tester.tap(find.text('REPLACE WATER'));
    await tester.pump();
    expect(controller.value.encode(), formal.encode());
    expect(
      find.text('WATER IMPORT READY — PRESS SAVE TO PERSIST'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('base-camp-editor-copy-json')));
    final exported = await Clipboard.getData(Clipboard.kTextPlain);
    final exportedWater = BaseCampWaterGeometryImport.parse(exported!.text!);
    expect(
      exportedWater.areas.map((area) => area.exclusionMasks.length).toList(),
      <int>[3, 0, 2, 2],
    );

    await tester.tap(find.byKey(const ValueKey('base-camp-editor-undo')));
    await tester.pump();
    await tester.tap(importButton);
    await _pumpRouteTransition(tester);
    await tester.tap(find.text('REPLACE WATER'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('base-camp-editor-save')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(pickerCalls, 3);
    final saved = controller.value;
    expect(
      saved.waterFx['water']!.effectiveAreas
          .map((area) => area.exclusionMasks.length)
          .toList(),
      <int>[3, 0, 2, 2],
    );
    expect(saved.routes, formal.routes);
    expect(saved.objects.keys, formal.objects.keys);
    expect(saved.soldierScale, formal.soldierScale);
    expect(saved.smokeFx.toJson(), formal.smokeFx.toJson());
    expect(saved.labels.keys, formal.labels.keys);
    expect(saved.staticSoldiers, formal.staticSoldiers);

    final reloaded = BaseCampMapConfigurationController(
      approvedWaterGeometryLoader: () async => approvedJson,
    );
    await reloaded.load();
    expect(
      reloaded.value.waterFx['water']!.effectiveAreas
          .map((area) => area.exclusionMasks.length)
          .toList(),
      <int>[3, 0, 2, 2],
    );
  });

  testWidgets(
    'invalid editor import leaves working and formal data unchanged',
    (tester) async {
      final formal = BaseCampMapConfiguration.defaults();
      final controller = BaseCampMapConfigurationController()
        ..resetForTesting(formal);
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: BaseCampMapEditorPage(
            configurationController: controller,
            waterDraftStore: BaseCampWaterDraftStore(),
            waterJsonPicker: () async => BaseCampImportedFile(
              name: 'invalid.json',
              mimeType: 'application/json',
              bytes: Uint8List.fromList(utf8.encode('{invalid')),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      final importButton = find.byKey(
        const ValueKey('base-camp-editor-import-water-json'),
      );
      expect(importButton, findsOneWidget);
      await tester.tap(importButton);
      await tester.pump();
      expect(find.textContaining('WATER IMPORT REJECTED'), findsOneWidget);
      expect(find.text('IMPORT WATER JSON?'), findsNothing);
      expect(controller.value.encode(), formal.encode());
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('base-camp-editor-undo')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

void _expectPointsMatch(List<Offset> actual, List<dynamic> source) {
  expect(actual, hasLength(source.length));
  for (var index = 0; index < source.length; index++) {
    final point = source[index] as Map<String, dynamic>;
    expect(actual[index].dx, (point['x'] as num).toDouble());
    expect(actual[index].dy, (point['y'] as num).toDouble());
  }
}

Map<String, dynamic> _deepCopy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

List<dynamic> _areas(Map<String, dynamic> value) =>
    (((value['waterFx'] as Map<String, dynamic>)['water']
            as Map<String, dynamic>)['areas']
        as List<dynamic>);

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Offset? _findInteriorPoint(Path path, {List<Path> rejectedBy = const []}) {
  final bounds = path.getBounds();
  for (var yStep = 1; yStep < 40; yStep++) {
    for (var xStep = 1; xStep < 40; xStep++) {
      final candidate = Offset(
        bounds.left + bounds.width * xStep / 40,
        bounds.top + bounds.height * yStep / 40,
      );
      if (path.contains(candidate) &&
          !rejectedBy.any((excluded) => excluded.contains(candidate))) {
        return candidate;
      }
    }
  }
  return null;
}
