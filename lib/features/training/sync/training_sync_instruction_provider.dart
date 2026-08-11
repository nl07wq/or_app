import 'training_sync_schema.dart';

class TrainingSyncInstructionProvider {
  const TrainingSyncInstructionProvider();

  String build() =>
      '''
TRAINING SYNC SCHEMA 1.0
出力はORLO Sync JSON Objectのみ。Markdownや説明文は禁止です。
dataTypeはtraining、schemaVersionは1.0です。
idempotencyKeyはpayload.session.recordIdと完全一致させてください。
Session fields: ${TrainingSyncSchema.sessionFields.join(', ')}
Exercise fields: ${TrainingSyncSchema.exerciseFields.join(', ')}
Equipment fields: ${TrainingSyncSchema.equipmentFields.join(', ')}
Set fields: ${TrainingSyncSchema.setFields.join(', ')}
Cardio fields: ${TrainingSyncSchema.cardioFields.join(', ')}
Preserve startTime and endTime only when formally recorded as offset ISO-8601 datetimes; otherwise set both to null and never infer either time. A Strength Calories Snapshot must contain estimatedStrengthCaloriesKcal, strengthWeightSnapshotKg, strengthCalculationMethod=strengthSessionMetsAcsmV1, and strengthCalculationVersion=1 together, or all four fields must be null. Never infer or reconstruct the snapshot.
exerciseIdはexerciseNameの正式な正規化Identity Keyです。推測は禁止です。
grade、Set type、Cardio purpose/type、Equipment IDはStable IDを使用してください。
Weightはkg、RestとDurationは秒、Distanceはkm、Speedはkm/hです。
確認不能なnullable Fieldはnullとし、Stretchは推測せず必ず明示してください。
SetはwarmUpまたはmain。Cardio purposeはwarmUp、main、cooldown。legacyUnknownは禁止です。
CardioにEquipment Fieldを追加しないでください。
Calories SnapshotはestimatedCaloriesKcal、weightSnapshotKg、calculationMethod=metsAcsmV1、calculationVersion=1を一式で出力するか、すべてnullにしてください。
overallEvaluation、exercise evaluation、nextTargetは明示された場合だけ出力してください。
未知Fieldや余計な文章を追加しないでください。
'''
          .trim();
}
