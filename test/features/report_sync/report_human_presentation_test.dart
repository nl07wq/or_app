import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/report_sync/models/morning_brief_record.dart';
import 'package:or_app/features/report_sync/services/report_human_presentation.dart';

void main() {
  test('holiday work presentation hides formal zero-duration artifacts', () {
    expect(ReportHumanPresentation.workText('公休日、実働0時間（0:00）'), '公休日');
    expect(ReportHumanPresentation.workText('通常勤務、実働8時間'), '通常勤務、実働8時間');
  });

  test('holiday display keeps human meaning without changing source model', () {
    const source = MorningBriefSectionDisplay(
      primaryText: '公休日 / 勤務0時間',
      supportingText: '0:00',
    );

    final display = ReportHumanPresentation.workDisplay(source, 'holiday');

    expect(display!.primaryText, '公休日');
    expect(display.supportingText, '公休日');
    expect(source.primaryText, '公休日 / 勤務0時間');
    expect(source.supportingText, '0:00');
  });
}
