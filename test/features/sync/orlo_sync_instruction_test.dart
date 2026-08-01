import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/sync/services/orlo_sync_instruction_provider.dart';

void main() {
  test(
    'common instruction is schema-backed and forbids guessing and prose',
    () {
      final text = const OrloSyncInstructionProvider().buildCommonInstruction();
      expect(text, contains('orlo-sync'));
      expect(text, contains('envelopeVersionは1'));
      expect(text, contains('schemaVersionは1.0'));
      expect(text, contains('確認できない値を推測しない'));
      expect(text, contains('JSON Objectのみ'));
      expect(text, contains('説明文やMarkdownを追加しない'));
      expect(text, contains('個別Payload Schemaは未提供'));
    },
  );
}
