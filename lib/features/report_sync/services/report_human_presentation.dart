import '../models/morning_brief_record.dart';

abstract final class ReportHumanPresentation {
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
