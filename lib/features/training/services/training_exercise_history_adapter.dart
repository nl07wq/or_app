import 'exercise_name_localization.dart';
import 'training_exercise_identity.dart';
import 'training_history_domain_service.dart';
import 'training_history_overview_adapter.dart';
import '../models/training_record_read_model.dart';

class TrainingExerciseHistoryAdapter {
  const TrainingExerciseHistoryAdapter({
    this.domain = const TrainingHistoryDomainService(),
    this.periods = const TrainingHistoryOverviewAdapter(),
  });

  final TrainingHistoryDomainService domain;
  final TrainingHistoryOverviewAdapter periods;

  List<ExerciseHistoryPoint> points(
    Iterable<TrainingRecordReadModel> records, {
    required TrainingHistoryOverviewPeriod period,
    DateTime? referenceDate,
  }) => [
    for (final point in domain.exerciseHistory(records))
      if (periods.includesOperationDate(
        point.operationDate,
        period: period,
        referenceDate: referenceDate,
      ))
        point,
  ];

  List<TrainingExerciseIdentity> identities(List<ExerciseHistoryPoint> points) {
    final latest = <TrainingExerciseIdentity, ExerciseHistoryPoint>{};
    for (final point in points) {
      latest[point.identity] = point;
    }
    final values = latest.values.toList()
      ..sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
    return [for (final point in values) point.identity];
  }

  List<ExerciseHistoryPoint> forIdentity(
    Iterable<ExerciseHistoryPoint> points,
    TrainingExerciseIdentity identity,
  ) => [
    for (final point in points)
      if (point.identity == identity) point,
  ]..sort((a, b) => _dateOf(a).compareTo(_dateOf(b)));

  String label(TrainingExerciseIdentity identity) {
    final name = exerciseDisplayName(identity.exerciseKey);
    return identity.equipmentKey == 'none'
        ? name
        : '$name · ${identity.equipmentKey.replaceFirst('catalog:', '')}';
  }

  DateTime _dateOf(ExerciseHistoryPoint point) =>
      point.startTime ?? DateTime.parse(point.operationDate);
}
