String periodicReportDecimal(double value) =>
    _withThousandsSeparators(value.toStringAsFixed(1));

String periodicReportInteger(num value) =>
    _withThousandsSeparators(value.round().toString());

String periodicReportNumber(double value) {
  final rounded = value.roundToDouble();
  return (value - rounded).abs() < 0.0001
      ? periodicReportInteger(rounded)
      : periodicReportDecimal(value);
}

String periodicReportSignedDecimal(double value) =>
    '${value >= 0 ? '+' : ''}${periodicReportDecimal(value)}';

String periodicReportDurationMinutes(double value) {
  final totalMinutes = value.round();
  final sign = totalMinutes < 0 ? '-' : '';
  final absoluteMinutes = totalMinutes.abs();
  final hours = absoluteMinutes ~/ 60;
  final minutes = (absoluteMinutes % 60).toString().padLeft(2, '0');
  return '$sign$hours:$minutes';
}

String _withThousandsSeparators(String value) {
  final parts = value.split('.');
  final signedInteger = parts.first;
  final sign = signedInteger.startsWith('-') ? '-' : '';
  final digits = sign.isEmpty ? signedInteger : signedInteger.substring(1);
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '$sign$buffer${parts.length == 1 ? '' : '.${parts[1]}'}';
}
