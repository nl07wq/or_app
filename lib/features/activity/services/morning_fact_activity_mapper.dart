import '../../../core/models/activity_data.dart';
import '../../../core/models/morning_data.dart';

class MorningFactActivityMapper {
  const MorningFactActivityMapper();

  ActivityData initialize({
    required MorningData morning,
    ActivityData? existingActivity,
  }) {
    if (existingActivity != null) return existingActivity;

    return ActivityData(
      date: DateTime.parse(morning.date),
      stepsEntered: false,
      carryOverEntered: false,
      plannedWork: _plannedWork(morning),
      trainingStatus: ActivityTrainingStatus.unconfirmed,
    );
  }

  String _plannedWork(MorningData morning) {
    if (!morning.workType.isWorking) return morning.workType.name;
    return '${morning.workType.name}: '
        '${morning.workStart}-${morning.workEnd} '
        '(break ${morning.workBreak})';
  }
}
