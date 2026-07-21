import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/cardio_entry.dart';

void main() {
  test('stable enum identifiers', () {
    expect(CardioType.values.map((value) => value.name), ['walking', 'running', 'exerciseBike', 'elliptical', 'treadmillWalking', 'treadmillRunning']);
    expect(CardioIntensity.values.map((value) => value.name), ['light', 'moderate', 'vigorous']);
  });
  test('MET lookup values', () {
    expect(cardioMet(CardioType.walking, CardioIntensity.light), 2.8);
    expect(cardioMet(CardioType.walking, CardioIntensity.moderate), 3.8);
    expect(cardioMet(CardioType.running, CardioIntensity.vigorous), 10.0);
    expect(cardioMet(CardioType.exerciseBike, CardioIntensity.moderate), 6.0);
    expect(cardioMet(CardioType.elliptical, CardioIntensity.moderate), 5.5);
    expect(cardioMet(CardioType.treadmillWalking, CardioIntensity.vigorous), 6.0);
    expect(cardioMet(CardioType.treadmillRunning, CardioIntensity.moderate), 8.3);
  });
  test('calorie formula and invalid inputs', () {
    expect(estimateCardioCalories(type: CardioType.exerciseBike, intensity: CardioIntensity.moderate, durationMinutes: 30, bodyWeightKg: 100), closeTo(315, .0001));
    for (final duration in [0, -1]) { expect(() => estimateCardioCalories(type: CardioType.walking, intensity: CardioIntensity.light, durationMinutes: duration, bodyWeightKg: 1), throwsArgumentError); }
    for (final weight in [0.0, -1.0]) { expect(() => estimateCardioCalories(type: CardioType.walking, intensity: CardioIntensity.light, durationMinutes: 1, bodyWeightKg: weight), throwsArgumentError); }
  });
  test('JSON, optional fields, notes, and validation', () {
    final entry = CardioEntry(type: CardioType.running, intensity: CardioIntensity.vigorous, durationMinutes: 30, distanceKm: 5, notes: ' note ', estimatedCalories: 400);
    final restored = CardioEntry.fromJson(entry.toJson());
    expect(restored.type, entry.type); expect(restored.intensity, entry.intensity); expect(restored.durationMinutes, 30); expect(restored.distanceKm, 5); expect(restored.notes, 'note'); expect(restored.estimatedCalories, 400);
    final optional = CardioEntry.fromJson(CardioEntry(type: CardioType.walking, intensity: CardioIntensity.light, durationMinutes: 1).toJson());
    expect(optional.distanceKm, isNull); expect(optional.notes, isNull); expect(optional.estimatedCalories, isNull);
    expect(CardioEntry(type: CardioType.walking, intensity: CardioIntensity.light, durationMinutes: 1, distanceKm: 0).distanceKm, 0);
    expect(() => CardioEntry(type: CardioType.walking, intensity: CardioIntensity.light, durationMinutes: 0), throwsArgumentError);
    expect(() => CardioEntry(type: CardioType.walking, intensity: CardioIntensity.light, durationMinutes: -1), throwsArgumentError);
    expect(() => CardioEntry(type: CardioType.walking, intensity: CardioIntensity.light, durationMinutes: 1, distanceKm: -1), throwsArgumentError);
    expect(() => CardioEntry.fromJson({'type': 'bad', 'intensity': 'light', 'durationMinutes': 1}), throwsArgumentError);
    expect(() => CardioEntry.fromJson({'type': 'walking', 'intensity': 'bad', 'durationMinutes': 1}), throwsArgumentError);
    expect(() => CardioEntry.fromJson({'type': 'walking', 'intensity': 'light', 'durationMinutes': 0}), throwsArgumentError);
  });
}
