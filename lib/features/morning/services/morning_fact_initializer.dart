import '../../../core/repositories/morning_repository.dart';
import '../models/morning_initial_values.dart';

class MorningFactInitializer {
  const MorningFactInitializer();

  Future<MorningInitialValues> initialize() async {
    try {
      final latest = await MorningRepository.loadLatest();
      if (latest == null) {
        return const MorningInitialValues.empty();
      }

      return MorningInitialValues(
        weight: latest.weight?.toString() ?? '',
        bodyFat: latest.bodyFat?.toString() ?? '',
        sleep: latest.sleepHours == null ? '' : _formatTime(latest.sleepHours!),
        sleepScore: latest.sleepScore?.toString() ?? '',
        hasPreviousRecord: true,
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
