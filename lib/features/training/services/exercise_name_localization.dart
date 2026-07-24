const _builtInExerciseNames = <String, String>{
  'benchpress': 'ベンチプレス',
  'dumbbellcurl': 'ダンベルカール',
  'latpulldown': 'ラットプルダウン',
  'legpress': 'レッグプレス',
  'shoulderpress': 'ショルダープレス',
  'inclinebenchpress': 'インクラインベンチプレス',
  'chestpress': 'チェストプレス',
  'seatedrow': 'シーテッドロー',
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
  return _normalizeExerciseName(exerciseDisplayName(name));
}

String _normalizeExerciseName(String name) {
  return name.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
}
