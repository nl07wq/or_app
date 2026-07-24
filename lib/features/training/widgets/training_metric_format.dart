String formatTrainingNumber(double value) {
  return value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

String formatTrainingNumberWithThousands(double value) {
  final parts = formatTrainingNumber(value).split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return parts.length == 1 ? whole : '$whole.${parts.last}';
}
