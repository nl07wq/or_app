/// Presentation-only formatting for kg-based derived Training volume.
class TrainingVolumeFormatter {
  const TrainingVolumeFormatter._();

  static TrainingVolumeDisplay display(double kilograms) {
    if (kilograms < 1000) {
      return TrainingVolumeDisplay(_number(kilograms), 'kg');
    }
    final tonnes = kilograms / 1000;
    return TrainingVolumeDisplay(
      _number(tonnes, decimals: tonnes < 10 ? 2 : 1),
      't',
    );
  }

  static String format(double kilograms) {
    final value = display(kilograms);
    return '${value.value} ${value.unit}';
  }

  static String axisLabel(double kilograms) {
    if (kilograms < 1000) return '${_number(kilograms)}kg';
    return '${_number(kilograms / 1000, decimals: 1)}t';
  }

  static String _number(double value, {int decimals = 2}) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value
        .toStringAsFixed(decimals)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class TrainingVolumeDisplay {
  const TrainingVolumeDisplay(this.value, this.unit);

  final String value;
  final String unit;
}
