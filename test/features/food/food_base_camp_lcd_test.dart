import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/food/food_catalog_page.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/repository/food_catalog_repository.dart';
import 'package:or_app/features/themes/base_camp/base_camp_presentation.dart';
import 'package:or_app/features/themes/base_camp/base_camp_retro_terminal.dart';
import 'package:or_app/features/themes/base_camp/base_camp_retro_theme.dart';

void main() {
  setUp(() {
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
  });

  for (final width in <double>[320, 375, 390, 430]) {
    for (final negative in <bool>[false, true]) {
      testWidgets('FOOD DATABASE uses LCD at ${width}dp INV=$negative', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        DeviceSettingsController.instance.update(
          DeviceSettingsController.instance.value.copyWith(
            baseCampLcdNegative: negative,
          ),
        );

        await tester.pumpWidget(
          _baseCampHarness(
            FoodCatalogPage(repository: _EmptyCatalogRepository()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BaseCampTerminalDisplay), findsOneWidget);
        expect(
          find.byKey(const ValueKey('base-camp-terminal-lcd-grid')),
          findsOneWidget,
        );
        final palette = tester
            .widget<BaseCampTerminalPaletteScope>(
              find.byType(BaseCampTerminalPaletteScope),
            )
            .palette;
        final controls = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('food-database-controls-glass')),
        );
        final decoration = controls.decoration as BoxDecoration;
        expect(decoration.color, palette.field);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('STANDARD FOOD DATABASE does not gain terminal LCD chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: FoodCatalogPage(repository: _EmptyCatalogRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BaseCampTerminalDisplay), findsNothing);
    final controls = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('food-database-controls-glass')),
    );
    expect(
      (controls.decoration as BoxDecoration).color,
      const Color(0x66141B24),
    );
  });
}

Widget _baseCampHarness(Widget child) => MaterialApp(
  theme: BaseCampRetroTheme.apply(ThemeData.light()),
  home: BaseCampPresentation(screen: BaseCampScreen.food, child: child),
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
