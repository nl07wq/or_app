import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/training/services/training_exercise_history_adapter.dart';
import 'package:or_app/features/training/services/training_exercise_identity.dart';
import 'package:or_app/features/training/services/training_history_domain_service.dart';

import 'training_v2_calculation_test_fixture.dart';

void main() {
  const adapter = TrainingExerciseHistoryAdapter();

  test('groups identities by canonical exercise key and orders by recency', () {
    final benchRack = _identity('Bench Press', 'hammer_strength_power_rack');
    final benchUnrecorded = _identity('Bench Press', null);
    final lat = _identity('Lat Pulldown', 'hammer_strength_lat_pulldown');
    final points = [
      _point('rack', '2026-08-01', benchRack),
      _point('lat', '2026-08-03', lat),
      _point('unrecorded', '2026-08-02', benchUnrecorded),
    ];

    final categories = adapter.categories(points);

    expect(categories.map((item) => item.label), ['ラットプルダウン', 'ベンチプレス']);
    final variants = adapter.equipmentVariants(points, categories.last.key);
    expect(variants.map((item) => item.label), [
      'EQUIPMENT NOT RECORDED',
      'HAMMER STRENGTH パワーラック',
    ]);
  });

  test('keeps each equipment variant identity when resolving history', () {
    final rack = _identity('Bench Press', 'hammer_strength_power_rack');
    final dumbbells = _identity('Bench Press', 'dumbbells');
    final points = [
      _point('rack', '2026-08-01', rack, weight: 50),
      _point('dumbbells', '2026-08-02', dumbbells, weight: 20),
    ];

    final variants = adapter.equipmentVariants(points, rack.exerciseKey);
    final rackVariant = variants.singleWhere((item) => item.identity == rack);
    final history = adapter.forIdentity(points, rackVariant.identity);

    expect(variants, hasLength(2));
    expect(history, hasLength(1));
    expect(history.single.recordId, 'rack');
    expect(history.single.maxWeight, 50);
  });

  test('does not use a shared presentation label as the equipment lookup', () {
    final catalog = _identity('Bench Press', 'custom_rack');
    final named = TrainingExerciseIdentity.v2(
      v2Exercise(
        name: 'Bench Press',
        equipmentId: null,
        equipmentName: 'Custom Rack',
      ),
    );
    final points = [
      _point('catalog', '2026-08-01', catalog, weight: 50),
      _point('named', '2026-08-02', named, weight: 20),
    ];

    final variants = adapter.equipmentVariants(points, catalog.exerciseKey);
    final catalogVariant = variants.singleWhere(
      (item) => item.identity == catalog,
    );

    expect(variants, hasLength(2));
    expect(variants.map((item) => item.label).toSet(), {'CUSTOM RACK'});
    expect(
      adapter.forIdentity(points, catalogVariant.identity).single.recordId,
      'catalog',
    );
  });

  test(
    'uses Japanese presentation for known named Equipment without changing identity',
    () {
      final knownNamed = TrainingExerciseIdentity.v2(
        v2Exercise(
          name: 'Leg Press',
          equipmentId: null,
          equipmentName: 'Hammer Strength Linear Leg Press',
        ),
      );
      final customNamed = TrainingExerciseIdentity.v2(
        v2Exercise(
          name: 'Leg Press',
          equipmentId: null,
          equipmentName: 'Custom Leg Press Attachment',
        ),
      );
      final points = [
        _point('known', '2026-08-01', knownNamed),
        _point('custom', '2026-08-02', customNamed),
      ];

      final variants = adapter.equipmentVariants(
        points,
        knownNamed.exerciseKey,
      );

      expect(knownNamed.equipmentKey, 'name:hammer strength linear leg press');
      expect(
        variants.singleWhere((item) => item.identity == knownNamed).label,
        'HAMMER STRENGTH リニアレッグプレス',
      );
      expect(
        variants.singleWhere((item) => item.identity == customNamed).label,
        'CUSTOM LEG PRESS ATTACHMENT',
      );
    },
  );
}

TrainingExerciseIdentity _identity(String name, String? equipmentId) =>
    TrainingExerciseIdentity.fromV1(
      exerciseName: name,
      equipmentId: equipmentId,
    );

ExerciseHistoryPoint _point(
  String recordId,
  String operationDate,
  TrainingExerciseIdentity identity, {
  double weight = 40,
}) => ExerciseHistoryPoint(
  recordId: recordId,
  operationDate: operationDate,
  startTime: null,
  identity: identity,
  maxWeight: weight,
  workingVolume: null,
  recordedVolume: weight * 10,
  workingSetCount: null,
  recordedSetCount: 1,
  recordedReps: 10,
  recordedRpeAverage: null,
  recordedRpeMax: null,
);
