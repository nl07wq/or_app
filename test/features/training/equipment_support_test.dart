import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/features/training/models/equipment.dart';
import 'package:or_app/features/training/models/training_exercise_controller.dart';
import 'package:or_app/features/training/services/equipment_catalog.dart';
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
      hasLength(8),
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

  testWidgets('equipment selector supports a selection and None', (
    tester,
  ) async {
    final controller = ValueNotifier<String?>(null);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EquipmentSelector(controller: controller)),
      ),
    );

    expect(find.text('Equipment'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);

    await tester.tap(find.byKey(const Key('equipment-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smith Machine'));
    await tester.pumpAndSettle();

    expect(controller.value, 'smith_machine');
    expect(find.text('Smith Machine'), findsOneWidget);

    await tester.tap(find.byKey(const Key('equipment-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();

    expect(controller.value, isNull);
    expect(find.text('None'), findsOneWidget);
  });
}
