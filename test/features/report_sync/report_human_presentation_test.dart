import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/report_sync/models/morning_brief_record.dart';
import 'package:or_app/features/report_sync/services/report_human_presentation.dart';
import 'package:or_app/features/report_sync/models/report_sync_envelope.dart';
import 'package:or_app/features/report_sync/models/daily_debrief_record.dart';
import 'package:or_app/features/report_sync/services/report_sync_instruction_provider.dart';

void main() {
  test('holiday work presentation hides formal zero-duration artifacts', () {
    expect(ReportHumanPresentation.workText('公休日、実働0時間（0:00）'), '公休日');
    expect(ReportHumanPresentation.workText('公休日で実働だった。'), '公休日');
    expect(ReportHumanPresentation.workText('通常勤務、実働8時間'), '通常勤務、実働8時間');
    expect(ReportHumanPresentation.workText('勤務日、実働0時間'), '勤務日、実働0時間');
  });

  test('holiday display keeps human meaning without changing source model', () {
    const source = MorningBriefSectionDisplay(
      primaryText: '公休日 / 勤務0時間',
      supportingText: '0:00',
    );

    final display = ReportHumanPresentation.workDisplay(source, 'holiday');

    expect(display!.primaryText, '公休日');
    expect(display.supportingText, isNull);
    expect(source.primaryText, '公休日 / 勤務0時間');
    expect(source.supportingText, '0:00');
  });

  test('brief and debrief prompts require the dedicated holiday branch', () {
    final registry = ReportSyncInstructionProviderRegistry.standard();
    final morning = registry
        .forType(ReportSyncExchangeType.morningBrief)
        .buildInstruction(
          operationDate: '2026-08-25',
          sourceRecordId: 'status:2026-08-25',
          sourceDigest: 'a' * 64,
        );
    final debrief = registry
        .forType(ReportSyncExchangeType.dailyDebrief)
        .buildInstruction(
          operationDate: '2026-08-25',
          dailyDebriefSources: DailyDebriefSources(
            dailyAggregate: DailyDebriefDailyAggregateReference(
              operationDate: '2026-08-25',
              sourceType: 'records',
              recordDigest: 'b' * 64,
            ),
            confirmation: DailyDebriefConfirmationReference(
              recordId: 'confirmation:2026-08-25',
              recordVersion: 2,
              revision: 1,
              snapshotDigest: '1234abcd',
              recordDigest: 'c' * 64,
            ),
            morningBrief: null,
          ),
          dailyDebriefSource: const {'dailyAggregate': <String, Object?>{}},
        );

    for (final prompt in [morning, debrief]) {
      expect(prompt, contains('complete human-readable WORK presentation'));
      expect(prompt, contains('exactly 公休日'));
      expect(prompt, contains('Preserve every formal zero value unchanged'));
    }
    expect(morning, contains('workDisplay.supportingText must be null'));
  });
}
