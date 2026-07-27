import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/features/training/models/equipment.dart';
import 'package:or_app/features/training/models/training_exercise_controller.dart';
import 'package:or_app/features/training/services/equipment_catalog.dart';
import 'package:or_app/features/training/services/exercise_equipment_mapping.dart';
import 'package:or_app/features/training/widgets/equipment_selector.dart';

void main() {
  test('legacy exercises deserialize without equipment', () {
    final exercise = TrainingExercise.fromJson({
      'exerciseName': 'BenchPress',
      'order': 1,
      'sets': <Map<String, dynamic>>[],
    });

    expect(exercise.equipmentId, isNull);
    expect(exercise.toJson(), isNot(contains('equipmentId')));
  });

  test('equipment ID serializes and controller copies preserve it', () {
    const equipmentId = 'smith_machine';
    final exercise = TrainingExercise.fromJson({
      'exerciseName': 'BenchPress',
      'order': 1,
      'sets': <Map<String, dynamic>>[],
      'equipmentId': equipmentId,
    });
    final controller = TrainingExerciseController(
      equipmentController: ValueNotifier(equipmentId),
    );
    addTearDown(controller.dispose);
    final copy = controller.clone();
    addTearDown(copy.dispose);

    expect(exercise.equipmentId, equipmentId);
    expect(exercise.toJson()['equipmentId'], equipmentId);
    expect(copy.equipmentController.value, equipmentId);
  });

  test('built-in equipment catalog contains unique extendable entities', () {
    expect(
      builtInEquipment.map((equipment) => equipment.id).toSet(),
      hasLength(builtInEquipment.length),
    );
    expect(
      builtInEquipment.map((equipment) => equipment.displayName),
      containsAll([
        'Bench Press Rack',
        'Smith Machine',
        '45° Leg Press',
        'Horizontal Leg Press',
        'Plate Loaded Leg Press',
        'Lat Pulldown',
        'Cable Machine',
        'Hack Squat Machine',
      ]),
    );
    expect(equipmentById('cable_machine')?.category, EquipmentCategory.cable);
  });

  test('every built-in equipment has a Japanese display name', () {
    expect(
      {
        for (final equipment in builtInEquipment)
          equipment.id: equipmentDisplayNameJa(equipment),
      },
      {
        'power_rack': 'パワーラック',
        'bench_press_rack': 'ベンチプレスラック',
        'smith_machine': 'スミスマシン',
        'hammer_strength_bench': 'ハンマーストレングス・ベンチ',
        'leg_press_45': '45°レッグプレス',
        'horizontal_leg_press': 'ホリゾンタルレッグプレス',
        'plate_loaded_leg_press': 'プレートロード・レッグプレス',
        'linear_leg_press': 'リニアレッグプレス',
        'squat_press': 'スクワットプレス',
        'lat_pulldown': 'ラットプルダウン',
        'technogym_lat_pulldown': 'テクノジム・ラットプルダウン',
        'life_fitness_lat_pulldown': 'ライフフィットネス・ラットプルダウン',
        'cable_machine': 'ケーブルマシン',
        'cable_station': 'ケーブルステーション',
        'hack_squat_machine': 'ハックスクワットマシン',
        'shoulder_press_machine': 'ショルダープレスマシン',
        'incline_bench_machine': 'インクラインベンチマシン',
        'chest_press_machine': 'チェストプレスマシン',
        'seated_row_machine': 'シーテッドロウマシン',
        'leg_curl_machine': 'レッグカールマシン',
        'dumbbells': 'ダンベル',
      },
    );
    expect(
      equipmentDisplayNameJa(
        const Equipment(
          id: 'future_equipment',
          displayName: 'Future Equipment',
          category: EquipmentCategory.machine,
        ),
      ),
      'Future Equipment',
    );
  });

  test('every built-in exercise references catalog equipment', () {
    for (final exercise in const [
      'BenchPress',
      'LatPulldown',
      'LegPress',
      'ShoulderPress',
      'InclineBenchPress',
      'ChestPress',
      'SeatedRow',
      'DumbbellCurl',
      'Squat',
      'LegCurl',
      'HackSquat',
    ]) {
      final ids = compatibleEquipmentIds(exercise);
      expect(ids, isNotEmpty, reason: exercise);
      expect(ids.every((id) => equipmentById(id) != null), isTrue);
    }

    expect(
      compatibleEquipment('BenchPress').map((item) => item.displayName),
      containsAll(['Power Rack', 'Smith Machine', 'Hammer Strength Bench']),
    );
    expect(
      compatibleEquipment('LegPress').map((item) => item.displayName),
      containsAll(['45° Leg Press', 'Linear Leg Press', 'Squat Press']),
    );
    expect(
      compatibleEquipment('LatPulldown').map((item) => item.displayName),
      containsAll([
        'Technogym Lat Pulldown',
        'Life Fitness Lat Pulldown',
        'Cable Station',
      ]),
    );
    expect(compatibleEquipmentIds('Custom Exercise'), isEmpty);
  });

  testWidgets('equipment selector follows the selected exercise', (
    tester,
  ) async {
    final exerciseController = TextEditingController(text: 'BenchPress');
    final controller = ValueNotifier<String?>(null);
    addTearDown(exerciseController.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EquipmentSelector(
            exerciseController: exerciseController,
            controller: controller,
          ),
        ),
      ),
    );

    expect(find.text('Equipment'), findsOneWidget);
    expect(find.text('なし'), findsOneWidget);

    await tester.tap(find.byKey(const Key('equipment-selector')));
    await tester.pumpAndSettle();
    expect(find.text('パワーラック'), findsOneWidget);
    expect(find.text('ハンマーストレングス・ベンチ'), findsOneWidget);
    expect(find.text('45°レッグプレス'), findsNothing);
    await tester.tap(find.text('スミスマシン'));
    await tester.pumpAndSettle();

    expect(controller.value, 'smith_machine');
    expect(find.text('スミスマシン'), findsOneWidget);

    exerciseController.text = 'LegPress';
    await tester.pump();

    expect(controller.value, isNull);
    expect(find.text('なし'), findsOneWidget);

    await tester.tap(find.byKey(const Key('equipment-selector')));
    await tester.pumpAndSettle();
    expect(find.text('45°レッグプレス'), findsOneWidget);
    expect(find.text('リニアレッグプレス'), findsOneWidget);
    expect(find.text('スクワットプレス'), findsOneWidget);
    expect(find.text('スミスマシン'), findsNothing);
    await tester.tap(find.text('45°レッグプレス'));
    await tester.pumpAndSettle();

    expect(controller.value, 'leg_press_45');

    exerciseController.text = 'My Custom Exercise';
    await tester.pump();

    expect(controller.value, isNull);
    expect(find.text('なし'), findsOneWidget);

    await tester.tap(find.byKey(const Key('equipment-selector')));
    await tester.pumpAndSettle();
    expect(find.text('パワーラック'), findsNothing);
    expect(find.text('45°レッグプレス'), findsNothing);
    expect(find.text('なし'), findsNWidgets(2));
  });

  testWidgets('selected equipment remains Japanese at 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final exerciseController = TextEditingController(text: 'LatPulldown');
    final controller = ValueNotifier<String?>('technogym_lat_pulldown');
    addTearDown(exerciseController.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EquipmentSelector(
            exerciseController: exerciseController,
            controller: controller,
          ),
        ),
      ),
    );

    expect(find.text('Equipment'), findsOneWidget);
    expect(find.text('テクノジム・ラットプルダウン'), findsOneWidget);
    expect(controller.value, 'technogym_lat_pulldown');
    expect(tester.takeException(), isNull);
  });
}
