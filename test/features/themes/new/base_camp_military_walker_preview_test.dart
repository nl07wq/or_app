import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/themes/new/widgets/base_camp_map.dart';
import 'package:or_app/features/themes/new/widgets/base_camp_military_walker_preview.dart';

void main() {
  testWidgets('walker renders all four directional views without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (final direction in BaseCampWalkerDirection.values)
                Expanded(
                  child: BaseCampMilitaryWalker(
                    direction: direction,
                    walking: true,
                    scale: 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    for (final direction in BaseCampWalkerDirection.values) {
      expect(
        find.byKey(ValueKey('base-camp-walker-${direction.name}')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview exposes direction, walk state, scale and comparison', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BaseCampMilitaryWalkerPreview())),
    );

    await tester.tap(
      find.byKey(const ValueKey('base-camp-walker-direction-right')),
    );
    await tester.tap(find.byKey(const ValueKey('base-camp-walker-idle')));
    await tester.tap(find.byKey(const ValueKey('base-camp-walker-scale-1')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('base-camp-walker-preview-main')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('base-camp-walker-preview-comparison')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('RESET long press opens the otherwise hidden walking preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BaseCampMap(onFacilityPressed: (_) {})),
      ),
    );

    await tester.longPress(
      find.byKey(const ValueKey('new-theme-base-camp-reset')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('BASE CAMP WALKING STUDY'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('base-camp-walker-preview-main')),
      findsOneWidget,
    );
  });
}
