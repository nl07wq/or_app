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
    expect(find.text('None'), findsOneWidget);

    await tester.tap(find.byKey(const Key('equipment-selector')));
    await tester.pumpAndSettle();
    expect(find.text('Power Rack'), findsOneWidget);
    expect(find.text('Hammer Strength Bench'), findsOneWidget);
    expect(find.text('45° Leg Press'), findsNothing);
    await tester.tap(find.text('Smith Machine'));
    await tester.pumpAndSettle();

    expect(controller.value, 'smith_machine');
    expect(find.text('Smith Machine'), findsOneWidget);

    exerciseController.text = 'LegPress';
    await tester.pump();

    expect(controller.value, isNull);
    expect(find.text('None'), findsOneWidget);

    await tester.tap(find.byKey(const Key('equipment-selector')));
    await tester.pumpAndSettle();
    expect(find.text('45° Leg Press'), findsOneWidget);
    expect(find.text('Linear Leg Press'), findsOneWidget);
    expect(find.text('Squat Press'), findsOneWidget);
    expect(find.text('Smith Machine'), findsNothing);
    await tester.tap(find.text('45° Leg Press'));
    await tester.pumpAndSettle();

    expect(controller.value, 'leg_press_45');

    exerciseController.text = 'My Custom Exercise';
    await tester.pump();

    expect(controller.value, isNull);
    expect(find.text('None'), findsOneWidget);

    await tester.tap(find.byKey(const Key('equipment-selector')));
    await tester.pumpAndSettle();
    expect(find.text('Power Rack'), findsNothing);
    expect(find.text('45° Leg Press'), findsNothing);
    expect(find.text('None'), findsNWidgets(2));
  });
}
