import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/food/food_catalog_page.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/repository/food_catalog_repository.dart';
import 'package:or_app/features/morning/widgets/body_card.dart';
import 'package:or_app/features/morning/widgets/foot_card.dart';
import 'package:or_app/features/themes/base_camp/base_camp_presentation.dart';
import 'package:or_app/features/themes/base_camp/base_camp_retro_terminal.dart';
import 'package:or_app/features/themes/base_camp/base_camp_retro_theme.dart';

void main() {
  setUp(() {
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
  });

  for (final negative in <bool>[false, true]) {
    final mode = negative ? 'inv' : 'light';
    testWidgets('captures STATUS retro instruments $mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      DeviceSettingsController.instance.update(
        DeviceSettingsController.instance.value.copyWith(
          baseCampLcdNegative: negative,
        ),
      );
      final weight = TextEditingController(text: '94.2');
      final bodyFat = TextEditingController(text: '31.9');
      final foot = TextEditingController(text: '3');
      addTearDown(weight.dispose);
      addTearDown(bodyFat.dispose);
      addTearDown(foot.dispose);
      await tester.pumpWidget(
        _baseCampHarness(
          BaseCampScreen.morning,
          Column(
            children: [
              BodyCard(
                weightController: weight,
                bodyFatController: bodyFat,
                weightUnmeasured: false,
                onWeightUnmeasured: () {},
                onWeightMeasured: () {},
                initiallyExpanded: true,
              ),
              const SizedBox(height: 12),
              FootCard(controller: foot, initiallyExpanded: true),
            ],
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(BaseCampRetroTerminalPanel),
        matchesGoldenFile('goldens/status_retro_instruments_$mode.png'),
      );
    });

    testWidgets('captures FOOD add form LCD $mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      DeviceSettingsController.instance.update(
        DeviceSettingsController.instance.value.copyWith(
          baseCampLcdNegative: negative,
        ),
      );
      await tester.pumpWidget(
        _baseCampHarness(
          BaseCampScreen.food,
          FoodCatalogEditorPage(repository: _EmptyCatalogRepository()),
          direct: true,
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(BaseCampRetroTerminalPanel),
        matchesGoldenFile('goldens/food_add_lcd_$mode.png'),
      );
    });

    testWidgets('captures FOOD database rhythm $mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      DeviceSettingsController.instance.update(
        DeviceSettingsController.instance.value.copyWith(
          baseCampLcdNegative: negative,
        ),
      );
      await tester.pumpWidget(
        _baseCampHarness(
          BaseCampScreen.food,
          FoodCatalogPage(
            repository: _EmptyCatalogRepository(<FoodCatalogEntry>[
              _catalogEntry(
                id: '11111111-1111-4111-8111-111111111111',
                name: '焼き鮭と玄米のセット',
              ),
              _catalogEntry(
                id: '22222222-2222-4222-8222-222222222222',
                name: 'PROTEIN BAR',
              ),
            ]),
          ),
          direct: true,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(BaseCampRetroTerminalPanel),
        matchesGoldenFile('goldens/food_database_lcd_$mode.png'),
      );
    });
  }
}

Widget _baseCampHarness(
  BaseCampScreen screen,
  Widget child, {
  bool direct = false,
}) => MaterialApp(
  theme: BaseCampRetroTheme.apply(ThemeData.light()),
  home: BaseCampPresentation(
    screen: screen,
    child: direct
        ? child
        : BaseCampRetroTerminalScreen(
            screenKey: 'visual-capture',
            child: Scaffold(
              body: BaseCampTerminalDisplay(
                margin: const EdgeInsets.all(8),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: child,
                ),
              ),
            ),
          ),
  ),
);

class _EmptyCatalogRepository implements FoodCatalogRepository {
  _EmptyCatalogRepository([this.entries = const <FoodCatalogEntry>[]]);

  final List<FoodCatalogEntry> entries;

  @override
  Future<void> archive(String foodId) async {}

  @override
  Future<void> create(FoodCatalogEntry entry) async {}

  @override
  Future<void> delete(String foodId) async {}

  @override
  Future<FoodCatalogEntry?> readById(String foodId) async => null;

  @override
  Future<List<FoodCatalogEntry>> list() async => entries;

  @override
  Future<void> update(FoodCatalogEntry entry) async {}
}

FoodCatalogEntry _catalogEntry({required String id, required String name}) {
  final timestamp = DateTime.utc(2026, 11, 16);
  return FoodCatalogEntry(
    foodId: id,
    name: name,
    category: FoodCatalogCategory.packagedFood,
    baseQuantity: FoodQuantityDefinition(
      value: 100,
      unit: FoodQuantityUnit.gram,
    ),
    nutrition: NutritionSnapshot(
      calories: 286,
      protein: 12.2,
      fat: 9.3,
      carbohydrate: 36.2,
    ),
    nutritionStatus: NutritionStatus.declared,
    provenance: FoodDataProvenance(
      sourceType: FoodProvenanceSourceType.userInput,
      capturedAt: timestamp,
    ),
    isArchived: false,
    packageQuantity: 1,
    packageUnit: FoodQuantityUnit.pack,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
