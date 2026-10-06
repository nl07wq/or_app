import '../../../core/repositories/morning_repository.dart';
import '../../../core/models/work_type.dart';
import '../../repositories/app_repository_container.dart';
import '../../status/services/status_latest_valid_values_resolver.dart';
import '../models/morning_initial_values.dart';

class MorningFactInitializer {
  const MorningFactInitializer();

  Future<MorningInitialValues> initialize({String? beforeOrOnLocalDate}) async {
    try {
      final scheduledWork = beforeOrOnLocalDate == null
          ? null
          : await AppRepositoryRegistry.container.schedules.findWorkForDate(
              beforeOrOnLocalDate,
            );
      final records = await MorningRepository.getAll();
      if (records.isEmpty) {
        return MorningInitialValues(
          weight: '',
          bodyFat: '',
          sleep: '',
          sleepScore: '',
          workType: scheduledWork == null ? null : WorkType.work,
          workStart: scheduledWork?.startTime,
          workEnd: scheduledWork?.endTime,
          workBreak: scheduledWork?.breakDuration,
        );
      }
      final values = StatusLatestValidValuesResolver.resolve(
        records,
        beforeOrOnLocalDate: beforeOrOnLocalDate,
      );

      return MorningInitialValues(
        weight: values.weight?.value.toString() ?? '',
        bodyFat: values.bodyFat?.value.toString() ?? '',
        sleep: values.sleepHours == null
            ? ''
            : _formatTime(values.sleepHours!.value),
        sleepScore: values.sleepScore?.value.toString() ?? '',
        hasPreviousRecord: true,
        workType: scheduledWork == null ? null : WorkType.work,
        workStart: scheduledWork?.startTime,
        workEnd: scheduledWork?.endTime,
        workBreak: scheduledWork?.breakDuration,
      );
    } catch (_) {
      return const MorningInitialValues.empty();
    }
  }

  String _formatTime(double hours) {
    final totalMinutes = (hours * 60).round();
    final hour = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;
    return '$hour:${minute.toString().padLeft(2, '0')}';
  }
}
