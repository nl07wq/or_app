import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/training/repository/training_record_id_generator.dart';

void main() {
  test('generates deterministic RFC 4122 UUID v4 with training prefix', () {
    var next = 0;
    final generator = TrainingRecordIdGenerator(nextInt: (_) => next++);

    final id = generator.generate();

    expect(id, 'training:00010203-0405-4607-8809-0a0b0c0d0e0f');
    expect(
      id,
      matches(
        RegExp(
          r'^training:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
          r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(id.split(':').last.split('-')[2][0], '4');
    expect('89ab', contains(id.split(':').last.split('-')[3][0]));
  });

  test('generates unique IDs from different random byte sequences', () {
    var next = 0;
    final generator = TrainingRecordIdGenerator(nextInt: (_) => next++ & 0xff);

    expect(generator.generate(), isNot(generator.generate()));
  });

  test('does not swallow random generation failures', () {
    final generator = TrainingRecordIdGenerator(
      nextInt: (_) => throw StateError('secure random failed'),
    );

    expect(generator.generate, throwsStateError);
  });

  test('Legacy ID is deterministic and independent of Map key order', () {
    const generator = TrainingLegacyIdGenerator();
    final first = generator.generate(
      sessionJson: {
        'date': '2026-07-26T10:00:00',
        'memo': 'memo',
        'exercises': [
          {'exerciseName': 'BenchPress', 'order': 0, 'sets': []},
        ],
      },
      sourceIndex: 4,
      duplicateOrdinal: 0,
    );
    final reordered = generator.generate(
      sessionJson: {
        'exercises': [
          {'sets': [], 'order': 0, 'exerciseName': 'BenchPress'},
        ],
        'memo': 'memo',
        'date': '2026-07-26T10:00:00',
      },
      sourceIndex: 4,
      duplicateOrdinal: 0,
    );

    expect(first, reordered);
    expect(first, matches(RegExp(r'^legacy-training:[0-9a-f]{8}:0000$')));
  });

  test('Legacy duplicate ordinal produces a distinct deterministic ID', () {
    const generator = TrainingLegacyIdGenerator();
    final json = <String, dynamic>{
      'date': '2026-07-26',
      'memo': '',
      'exercises': const [],
    };

    final first = generator.generate(
      sessionJson: json,
      sourceIndex: 0,
      duplicateOrdinal: 0,
    );
    final duplicate = generator.generate(
      sessionJson: json,
      sourceIndex: 0,
      duplicateOrdinal: 1,
    );

    expect(first, isNot(duplicate));
    expect(duplicate, endsWith(':0001'));
  });
}
