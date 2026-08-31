import '../models/morning_brief_record.dart';

abstract final class ReportHumanPresentation {
  static String recordIdentity(String baseIdentity, int revision) =>
      revision <= 1 ? baseIdentity : '$baseIdentity-Rev$revision';

  static String revisionLabel(int revision) =>
      revision <= 1 ? 'INITIAL' : 'REV $revision';

  static String analysisText(String value) {
    var normalized = value
        .replaceAll('直近文脈の平均', '直近1週間の平均')
        .replaceAll('文脈の平均', '直近平均')
        .replaceAll('直近文脈から', '直近1週間の状態から')
        .replaceAll('文脈から', '最近の状態から')
        .replaceAll('直近文脈', '直近1週間の状態');
    normalized = normalized
        .replaceAll(RegExp('最近のcontext', caseSensitive: false), '最近の状態')
        .replaceAll(RegExp('recent context', caseSensitive: false), '直近1週間の状態')
        .replaceAll(RegExp(r'\bcontext\b', caseSensitive: false), '最近の状態')
        .replaceAll(RegExp('callback', caseSensitive: false), '入力情報')
        .replaceAll(RegExp(r'\bJSON\b', caseSensitive: false), '入力情報')
        .replaceAll(RegExp(r'入力情報\s+入力情報'), '入力情報');
    normalized = normalized
        .replaceAllMapped(
          RegExp(r'足底筋膜炎は\s*(\d+(?:\.\d+)?)'),
          (match) => '足底筋膜炎LVは${match[1]}',
        )
        .replaceAllMapped(
          RegExp(r'足底筋膜炎\s*([:：])\s*(\d+(?:\.\d+)?)'),
          (match) => '足底筋膜炎${match[1]} LV.${match[2]}',
        )
        .replaceAllMapped(
          RegExp(r'足底筋膜炎\s*(\d+(?:\.\d+)?)'),
          (match) => '足底筋膜炎LV.${match[1]}',
        );
    return normalized;
  }

  static bool isHoliday(String value) {
    final normalized = value.toLowerCase();
    return value.contains('公休日') || normalized.contains('holiday');
  }

  static String workText(String value) {
    if (!isHoliday(value)) return value;
    return '公休日';
  }

  static MorningBriefSectionDisplay? workDisplay(
    MorningBriefSectionDisplay? display,
    String workText,
  ) {
    if (display == null) return null;
    final holiday =
        isHoliday(workText) ||
        isHoliday(display.primaryText) ||
        (display.supportingText != null && isHoliday(display.supportingText!));
    if (!holiday) return display;
    return const MorningBriefSectionDisplay(
      primaryText: '公休日',
      supportingText: null,
    );
  }
}
