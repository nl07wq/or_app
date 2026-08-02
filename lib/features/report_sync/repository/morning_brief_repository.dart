import '../models/morning_brief_record.dart';

abstract interface class MorningBriefRepository {
  Future<MorningBriefRecord> create(MorningBriefRecord record);
  Future<MorningBriefRecord?> readByLocalDate(String localDate);
  Future<List<MorningBriefRecord>> list();
}
