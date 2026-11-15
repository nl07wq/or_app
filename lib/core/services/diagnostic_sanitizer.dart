const int diagnosticTextLimit = 240;

/// Sanitizes observable navigation input without retaining query values,
/// fragments, credentials, or arbitrary browser state payloads.
Map<String, Object?> sanitizeDiagnosticUri(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const <String, Object?>{'present': false};
  }
  final bounded = _bounded(raw.trim(), diagnosticTextLimit);
  final parsed = Uri.tryParse(bounded);
  if (parsed == null) {
    return <String, Object?>{
      'present': true,
      'valid': false,
      'input': _withoutSensitiveSuffix(bounded),
    };
  }
  return <String, Object?>{
    'present': true,
    'valid': true,
    if (parsed.scheme.isNotEmpty) 'scheme': parsed.scheme,
    if (parsed.host.isNotEmpty) 'host': parsed.host,
    if (parsed.hasPort) 'port': parsed.port,
    'path': _bounded(parsed.path, diagnosticTextLimit),
    if (parsed.queryParameters.isNotEmpty)
      'queryKeys': parsed.queryParameters.keys
          .where((key) => !_sensitiveKey(key))
          .take(12)
          .toList(growable: false),
    'hasFragment': parsed.fragment.isNotEmpty,
  };
}

String sanitizeDiagnosticText(
  String value, {
  int limit = diagnosticTextLimit,
}) => _bounded(value.replaceAll(RegExp(r'[\r\n\t]+'), ' '), limit);

String _withoutSensitiveSuffix(String value) {
  final query = value.indexOf('?');
  final fragment = value.indexOf('#');
  final cut = <int>[query, fragment]
      .where((index) => index >= 0)
      .fold<int>(
        value.length,
        (current, index) => index < current ? index : current,
      );
  return _bounded(value.substring(0, cut), diagnosticTextLimit);
}

bool _sensitiveKey(String key) {
  final lower = key.toLowerCase();
  return lower.contains('token') ||
      lower.contains('secret') ||
      lower.contains('password') ||
      lower.contains('auth');
}

String _bounded(String value, int limit) => value.length <= limit
    ? value
    : '${value.substring(0, limit)}...[TRUNCATED]';
