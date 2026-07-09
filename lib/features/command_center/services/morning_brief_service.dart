import '../core/command_engine.dart';
import '../core/morning_brief_builder.dart';
import '../models/morning_brief.dart';
import '../models/morning_fact.dart';

class MorningBriefService {
  const MorningBriefService();

  MorningBrief build(MorningFact fact) {
    final result = CommandEngine(morningFact: fact).buildResult();

    return const MorningBriefBuilder().build(result, fact);
  }
}
