import '../models/morning_brief_record.dart';

abstract final class ReportHumanPresentation {
  static bool isHoliday(String value) {
    final normalized = value.toLowerCase();
    return value.contains('公休日') || normalized.contains('holiday');
  }

  static String workText(String value) {
    if (!isHoliday(value)) return value;
    return _holidayText(value);
  }

  static String _holidayText(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'(?:実働|勤務)\s*0(?:\.0)?\s*時間'), '')
        .replaceAll(RegExp(r'(?<!\d)0:00(?!\d)'), '')
        .replaceAll(RegExp(r'[（）()]'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'^[\s、,・:/-]+|[\s、,・:/-]+$'), '')
        .trim();
    return sanitized.isEmpty ? '公休日' : sanitized;
  }

  static MorningBriefSectionDisplay? workDisplay(
    MorningBriefSectionDisplay? display,
    String workText,
  ) {
    if (display == null || !isHoliday(workText)) return display;
    return MorningBriefSectionDisplay(
      primaryText: _holidayText(display.primaryText),
      supportingText: display.supportingText == null
          ? null
          : _holidayText(display.supportingText!),
    );
  }
}
