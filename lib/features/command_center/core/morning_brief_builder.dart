import '../models/command_result.dart';
import '../models/morning_brief.dart';
import '../models/morning_fact.dart';

class MorningBriefBuilder {
  const MorningBriefBuilder();

  MorningBrief build(CommandResult result, MorningFact fact) {
    final summary = <String>[];

    if (fact.sleepMinutes < 360) {
      summary.add('睡眠不足です');
    } else {
      summary.add('睡眠は十分です');
    }

    if (fact.fatigue >= 4) {
      summary.add('疲労が蓄積しています');
    } else {
      summary.add('疲労は軽度です');
    }

    if (fact.plantarPain >= 5) {
      summary.add('足底筋膜炎に注意が必要です');
    } else {
      summary.add('足底の状態は安定しています');
    }

    if (fact.weight >= 106.0) {
      summary.add('体重は基準値を超えています');
    } else {
      summary.add('体重は良好です');
    }

    return MorningBrief(
      operationStatus: result.operationStatus,

      situation:
          '体重：${fact.weight.toStringAsFixed(1)}kg\n'
          '睡眠：${fact.sleepMinutes}分\n'
          '疲労：${fact.fatigue}\n'
          '足底：${fact.plantarPain}',

      summary: summary.join('\n'),

      commanderIntent: result.commanderIntent,

      actions: result.highestPriority.action == null
          ? []
          : [result.highestPriority.action!],
    );
  }
}
