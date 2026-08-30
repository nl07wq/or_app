import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/food_page.dart';
import 'package:or_app/features/training/training_page.dart';

void main() {
  testWidgets('training uses human-facing Japanese descriptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: TrainingPage()));
    expect(find.text('ChatGPTから\nトレーニング記録を取り込みます。'), findsOneWidget);
    expect(find.text('トレーニング記録をもとに、\n次回のプランを作成します。'), findsOneWidget);
    expect(find.text('トレーニング記録を選択して、\n分析レポートを作成・確認します。'), findsOneWidget);
    expect(find.textContaining('Operation Reboot Report'), findsNothing);
  });

  testWidgets('food uses the ChatGPT import description', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: FoodPage()));
    expect(find.text('ChatGPTから\n食事記録を取り込みます。'), findsOneWidget);
    expect(find.textContaining('Operation Reboot Report'), findsNothing);
  });
}
