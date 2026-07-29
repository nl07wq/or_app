class TrainingEquipmentSnapshot {
  final String? catalogId;
  final String name;

  TrainingEquipmentSnapshot({String? catalogId, required String name})
    : catalogId = _normalizeOptional(catalogId),
      name = name.trim() {
    if (this.name.isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'Equipment snapshot name must not be empty.',
      );
    }
  }

  Map<String, Object?> toJson() => {'catalogId': catalogId, 'name': name};

  factory TrainingEquipmentSnapshot.fromJson(Map<String, Object?> json) {
    final catalogId = json['catalogId'];
    final name = json['name'];
    if (catalogId != null && catalogId is! String) {
      throw const FormatException('Invalid TRAINING equipment catalogId.');
    }
    if (name is! String) {
      throw const FormatException('Invalid TRAINING equipment name.');
    }
    return TrainingEquipmentSnapshot(
      catalogId: catalogId as String?,
      name: name,
    );
  }

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
