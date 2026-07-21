import 'food_item.dart';

enum MealTemplateMealType { breakfast, lunch, dinner }

enum MealTemplateEntryReferenceType { foodItem, recipe }

class MealTemplateEntry {
  final MealTemplateEntryReferenceType referenceType;
  final String referenceId;
  final double amount;
  final FoodUnit unit;

  MealTemplateEntry({
    required this.referenceType,
    required this.referenceId,
    required this.amount,
    required this.unit,
  }) {
    if (referenceId.trim().isEmpty) {
      throw ArgumentError.value(
        referenceId,
        'referenceId',
        'Reference ID must not be empty.',
      );
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Amount must be finite and greater than zero.',
      );
    }
  }

  MealTemplateEntry copyWith({
    MealTemplateEntryReferenceType? referenceType,
    String? referenceId,
    double? amount,
    FoodUnit? unit,
  }) {
    return MealTemplateEntry(
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'referenceType': referenceType.name,
      'referenceId': referenceId,
      'amount': amount,
      'unit': unit.name,
    };
  }

  factory MealTemplateEntry.fromJson(Map<String, dynamic> json) {
    return MealTemplateEntry(
      referenceType: MealTemplateEntryReferenceType.values.byName(
        json['referenceType'] as String,
      ),
      referenceId: json['referenceId'] as String,
      amount: (json['amount'] as num).toDouble(),
      unit: FoodUnit.values.byName(json['unit'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MealTemplateEntry &&
        other.referenceType == referenceType &&
        other.referenceId == referenceId &&
        other.amount == amount &&
        other.unit == unit;
  }

  @override
  int get hashCode => Object.hash(referenceType, referenceId, amount, unit);
}

class MealTemplate {
  final String id;
  final String name;
  final MealTemplateMealType mealType;
  final List<MealTemplateEntry> entries;
  final DateTime createdAt;
  final DateTime updatedAt;

  MealTemplate({
    required this.id,
    required this.name,
    required this.mealType,
    required List<MealTemplateEntry> entries,
    required this.createdAt,
    required this.updatedAt,
  }) : entries = List.unmodifiable(entries) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'ID must not be empty.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Name must not be empty.');
    }
  }

  MealTemplate copyWith({
    String? id,
    String? name,
    MealTemplateMealType? mealType,
    List<MealTemplateEntry>? entries,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MealTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      mealType: mealType ?? this.mealType,
      entries: entries ?? this.entries,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mealType': mealType.name,
      'entries': entries.map((entry) => entry.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MealTemplate.fromJson(Map<String, dynamic> json) {
    return MealTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      mealType: MealTemplateMealType.values.byName(json['mealType'] as String),
      entries: (json['entries'] as List)
          .map(
            (entry) => MealTemplateEntry.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MealTemplate &&
        other.id == id &&
        other.name == name &&
        other.mealType == mealType &&
        _listEquals(other.entries, entries) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    mealType,
    Object.hashAll(entries),
    createdAt,
    updatedAt,
  );

  static bool _listEquals<T>(List<T> first, List<T> second) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;

    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
