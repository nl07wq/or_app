class HistoricalImportDifference {
  final String field;
  final Object? current;
  final Object? incoming;

  const HistoricalImportDifference({
    required this.field,
    required this.current,
    required this.incoming,
  });
}

List<HistoricalImportDifference> historicalImportDifferences(
  Object? current,
  Object? incoming, {
  String path = '',
}) {
  final differences = <HistoricalImportDifference>[];
  _collectDifferences(current, incoming, path, differences);
  return List.unmodifiable(differences);
}

void _collectDifferences(
  Object? current,
  Object? incoming,
  String path,
  List<HistoricalImportDifference> output,
) {
  if (current is Map && incoming is Map) {
    final keys = <String>{
      ...current.keys.map((key) => key.toString()),
      ...incoming.keys.map((key) => key.toString()),
    }.toList()..sort();
    for (final key in keys) {
      _collectDifferences(
        current[key],
        incoming[key],
        path.isEmpty ? key : '$path.$key',
        output,
      );
    }
    return;
  }
  if (current is List && incoming is List) {
    final length = current.length > incoming.length
        ? current.length
        : incoming.length;
    for (var index = 0; index < length; index++) {
      _collectDifferences(
        index < current.length ? current[index] : null,
        index < incoming.length ? incoming[index] : null,
        '$path[$index]',
        output,
      );
    }
    return;
  }
  if (current != incoming) {
    output.add(
      HistoricalImportDifference(
        field: path.isEmpty ? r'$' : path,
        current: current,
        incoming: incoming,
      ),
    );
  }
}
