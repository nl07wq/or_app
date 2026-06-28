import '../models/morning_data.dart';

class MorningRepository {
  static final List<MorningData> _records = [];

  static void add(MorningData data) {
    _records.add(data);
  }

  static List<MorningData> getAll() {
    return List.unmodifiable(_records);
  }

  static void clear() {
    _records.clear();
  }
}
