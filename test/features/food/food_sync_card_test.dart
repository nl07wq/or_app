import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/theme/app_theme.dart';
import 'package:or_app/features/food/widgets/food_sync_card.dart';

void main() {
  testWidgets('food report sync card contains only its sync action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StandardTheme.theme,
        home: const Scaffold(body: FoodSyncCard()),
      ),
    );

    expect(find.text('SYNC FOOD'), findsOneWidget);
    expect(find.text('FOOD REPORT SYNC'), findsNothing);
  });
}
