import 'package:flutter/material.dart';

import '../models/command_result.dart';
import '../models/morning_brief.dart';
import '../models/morning_fact.dart';
import '../models/commander_message.dart';
import '../models/commander_warning.dart';


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

      operationId: _buildOperationId(),
      commanderMessage: CommanderMessage(
        title: 'ARGO',
        message: buildComment(fact),
        recommendations: buildRecommendations(fact),
      ),
      commanderWarnings: buildWarnings(fact),

      states: result.states,
    );
  }

  String buildComment(MorningFact fact) {
    if (fact.sleepMinutes < 360) {
      return '睡眠不足が確認されています。今日は回復を優先してください。';
    }

    if (fact.fatigue >= 4) {
      return '疲労が高めです。無理な負荷は避けましょう。';
    }

    if (fact.plantarPain >= 5) {
      return '足底への負荷を抑えた運用を推奨します。';
    }

    return '本日の状態は概ね良好です。Commander Intentを優先して行動してください。';
  }

  List<String> buildRecommendations(MorningFact fact) {
    final list = <String>[];

    if (fact.sleepMinutes < 360) {
      list.add('昼寝20〜30分を検討');
    }

    if (fact.weight >= 106) {
      list.add('夕食の炭水化物を控えめにする');
    }

    if (fact.fatigue >= 4) {
      list.add('トレーニング強度を1段階下げる');
    }

    if (fact.plantarPain >= 5) {
      list.add('ウォーキング時間を短縮する');
    }

    if (list.isEmpty) {
      list.add('現在の生活リズムを維持');
    }

    return list;
  }

  List<CommanderWarning> buildWarnings(MorningFact fact) {
    final list = <CommanderWarning>[];

    if (fact.sleepMinutes < 360) {
      list.add(
        const CommanderWarning(
          title: '睡眠不足',
          icon: Icons.bedtime,
          color: Colors.orange,
        ),
      );
    }

    if (fact.fatigue >= 4) {
      list.add(
        const CommanderWarning(
          title: '疲労蓄積',
          icon: Icons.battery_alert,
          color: Colors.orange,
        ),
      );
    }

    if (fact.plantarPain >= 5) {
      list.add(
        const CommanderWarning(
          title: '足底筋膜炎',
          icon: Icons.directions_walk,
          color: Colors.red,
        ),
      );
    }

    if (fact.weight >= 106) {
      list.add(
        const CommanderWarning(
          title: '体重超過',
          icon: Icons.monitor_weight,
          color: Colors.amber,
        ),
      );
    }

    return list;
  }

  String _buildOperationId() {
    final now = DateTime.now();

    final y = now.year;
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');

    return 'MB-$y-$m-$d';
  }
}
