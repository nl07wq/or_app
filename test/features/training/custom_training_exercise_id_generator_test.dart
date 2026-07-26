import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/training/repository/custom_training_exercise_id_generator.dart';

void main() {
  test('generates RFC 4122 UUID v4 with custom exercise prefix', () {
    var next = 0;
    final generator = CustomTrainingExerciseIdGenerator(nextInt: (_) => next++);

    final id = generator.generate();

    expect(
      id,
      matches(
        RegExp(
          r'^custom-exercise:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(id.substring('custom-exercise:'.length), startsWith('00010203'));
  });

  test('generates unique IDs from distinct random bytes', () {
    var next = 0;
    final generator = CustomTrainingExerciseIdGenerator(
      nextInt: (_) => next++ % 256,
    );

    expect(generator.generate(), isNot(generator.generate()));
  });

  test('does not swallow random generation failure', () {
    final generator = CustomTrainingExerciseIdGenerator(
      nextInt: (_) => throw StateError('secure random failed'),
    );

    expect(generator.generate, throwsStateError);
  });

  test('rejects an injected byte outside the valid range', () {
    final generator = CustomTrainingExerciseIdGenerator(nextInt: (_) => 256);

    expect(generator.generate, throwsStateError);
  });

  test('legacy ID is stable for the same exercise identity key', () {
    const generator = CustomTrainingExerciseLegacyIdGenerator();

    expect(
      generator.generate(' My_Custom Move '),
      generator.generate('my custom-move'),
    );
    expect(
      generator.generate('My Move'),
      matches(RegExp(r'^legacy-custom-exercise:[0-9a-f]{8}$')),
    );
  });
}
