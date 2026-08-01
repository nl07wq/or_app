import '../models/orlo_sync_models.dart';

class OrloSyncInstructionProvider {
  const OrloSyncInstructionProvider();

  String buildCommonInstruction() =>
      '''
ORLO SYNC FORMAT

出力はJSON Objectのみとし、説明文やMarkdownを追加しないでください。
formatは「${OrloSyncEnvelope.format}」、envelopeVersionは${OrloSyncEnvelope.currentEnvelopeVersion}です。
dataTypeはtraining、food、dailyLogのいずれか、schemaVersionは${OrloSyncEnvelope.currentSchemaVersion}です。
必須Field: format, envelopeVersion, schemaVersion, dataType, packageId, idempotencyKey, source, operationDate, payload。
Stable IDと単位は入力情報どおりに維持してください。
確認できない値を推測しないでください。nullが許可されたFieldだけnullを使用してください。
余計なField、自然文、コメントを出力しないでください。
個別Payload Schemaは未提供です。この共通指示だけでTRAINING、FOOD、DAILY LOGのPayloadを生成しないでください。
'''
          .trim();
}
