import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/food/food_catalog_page.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
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
  @override
  Future<void> archive(String foodId) async {}

  @override
  Future<void> create(FoodCatalogEntry entry) async {}

  @override
  Future<void> delete(String foodId) async {}

  @override
  Future<FoodCatalogEntry?> readById(String foodId) async => null;

  @override
  Future<List<FoodCatalogEntry>> list() async => const [];

  @override
  Future<void> update(FoodCatalogEntry entry) async {}
}
