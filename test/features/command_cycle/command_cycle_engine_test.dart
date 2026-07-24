import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/command_cycle/services/command_cycle_engine.dart';
import 'package:or_app/features/morning_fact/models/morning_fact.dart';
import 'package:or_app/features/training/models/statistics_result.dart';
import 'package:or_app/features/training/models/training_summary.dart';

void main() {
  test('builds an empty state when no module is registered', () {
    const engine = CommandCycleEngine();

    final state = engine.build();

    expect(state.trainingSummary, isNull);
    expect(state.morningFact, isNull);
  });

  test('registers a training summary without modifying module data', () {
    const trainingSummary = TrainingSummary(
      historySummary: null,
      progressionResult: null,
      statisticsResult: StatisticsResult(
        totalVolume: 1200,
        workingSets: 3,
        totalRepetitions: 24,
        averageWeight: 50,
        heaviestSet: null,
      ),
      personalRecordResult: null,
    );
    const emptyEngine = CommandCycleEngine();

    final registeredEngine = emptyEngine.registerTrainingSummary(
      trainingSummary,
    );
    final state = registeredEngine.build();

    expect(state.trainingSummary, same(trainingSummary));
    expect(state.trainingSummary?.statisticsResult.totalVolume, 1200);
    expect(emptyEngine.build().trainingSummary, isNull);
  });

  test('later training registration returns an independent state', () {
    const firstSummary = TrainingSummary(
      historySummary: null,
      progressionResult: null,
      statisticsResult: StatisticsResult(
        totalVolume: 1200,
        workingSets: 3,
        totalRepetitions: 24,
        averageWeight: 50,
        heaviestSet: null,
      ),
      personalRecordResult: null,
    );
    const secondSummary = TrainingSummary(
      historySummary: null,
      progressionResult: null,
      statisticsResult: StatisticsResult(
        totalVolume: 2000,
        workingSets: 4,
        totalRepetitions: 32,
        averageWeight: 62.5,
        heaviestSet: null,
      ),
      personalRecordResult: null,
    );
    final firstEngine = const CommandCycleEngine().registerTrainingSummary(
      firstSummary,
    );

    final secondEngine = firstEngine.registerTrainingSummary(secondSummary);

    expect(firstEngine.build().trainingSummary, same(firstSummary));
    expect(secondEngine.build().trainingSummary, same(secondSummary));
  });

  test('registers MorningFact independently in either module order', () {
    const morningFact = MorningFact(condition: 4, hydration: 500);
    const trainingSummary = TrainingSummary(
      historySummary: null,
      progressionResult: null,
      statisticsResult: StatisticsResult(
        totalVolume: 1200,
        workingSets: 3,
        totalRepetitions: 24,
        averageWeight: 50,
        heaviestSet: null,
      ),
      personalRecordResult: null,
    );

    final morningFirst = const CommandCycleEngine()
        .registerMorningFact(morningFact)
        .registerTrainingSummary(trainingSummary)
        .build();
    final trainingFirst = const CommandCycleEngine()
        .registerTrainingSummary(trainingSummary)
        .registerMorningFact(morningFact)
        .build();

    expect(morningFirst.morningFact, same(morningFact));
    expect(morningFirst.trainingSummary, same(trainingSummary));
    expect(trainingFirst.morningFact, same(morningFact));
    expect(trainingFirst.trainingSummary, same(trainingSummary));
  });
}
