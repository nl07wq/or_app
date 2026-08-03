const _builtInExerciseNames = <String, String>{
  'benchpress': 'ベンチプレス',
  'dumbbellcurl': 'ダンベルカール',
  'latpulldown': 'ラットプルダウン',
  'legpress': 'レッグプレス',
  'shoulderpress': 'ショルダープレス',
  'inclinebenchpress': 'インクラインベンチプレス',
  'chestpress': 'チェストプレス',
  'seatedrow': 'シーテッドロー',
  'facepull': 'フェイスプル',
  'squat': 'スクワット',
  'legcurl': 'レッグカール',
  'hacksquat': 'ハックスクワット',
};

String exerciseDisplayName(String name) {
  final trimmedName = name.trim();
  return _builtInExerciseNames[_normalizeExerciseName(trimmedName)] ??
      trimmedName;
}

String exerciseIdentityKey(String name) {
  final normalizedName = _normalizeExerciseName(name);
  if (_builtInExerciseNames.containsKey(normalizedName)) {
    return normalizedName;
  }
  for (final entry in _builtInExerciseNames.entries) {
    if (_normalizeExerciseName(entry.value) == normalizedName) {
      return entry.key;
    }
  }
  return normalizedName;
}

String _normalizeExerciseName(String name) {
  return name.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
}
