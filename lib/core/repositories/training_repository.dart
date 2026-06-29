import '../models/training_data.dart';

class TrainingRepository {
  static final List<TrainingData> _records = [];

  static void add(TrainingData data) {
    _records.add(data);
  }

  static List<TrainingData> getAll() {
    return List.unmodifiable(_records);
  }

  static void clear() {
    _records.clear();
  }
}
