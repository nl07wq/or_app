import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/shift_preset.dart';
import 'package:or_app/core/services/shift_preset_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'uses the exact formal defaults when no preference has been saved',
    () async {
      final presets = await ShiftPresetPreferences.load();

      expect(
        presets.map(
          (preset) =>
              (preset.name, preset.startTime, preset.endTime, preset.breakTime),
        ),
        [
          ('早番', '07:00', '18:00', '01:00'),
          ('中番', '11:00', '18:00', '01:00'),
          ('遅番', '15:15', '00:15', '01:00'),
        ],
      );
    },
  );

  test('persists four presets but rejects a fifth', () async {
    final presets = [
      ...ShiftPresetPreferences.defaults,
      const ShiftPreset(
        id: 'shift_custom',
        name: 'OPEN',
        startTime: '22:00',
        endTime: '06:00',
        breakTime: '01:00',
        order: 3,
      ),
    ];

    await ShiftPresetPreferences.save(presets);
    expect((await ShiftPresetPreferences.load()).map((preset) => preset.name), [
      '早番',
      '中番',
      '遅番',
      'OPEN',
    ]);
    await expectLater(
      ShiftPresetPreferences.save([...presets, presets.first]),
      throwsArgumentError,
    );
  });

  test('reloads presets in their persisted order', () async {
    final reordered = [
      ShiftPresetPreferences.defaults[2].copyWith(order: 0),
      ShiftPresetPreferences.defaults[0].copyWith(order: 1),
      ShiftPresetPreferences.defaults[1].copyWith(order: 2),
    ];

    await ShiftPresetPreferences.save(reordered);

    final loaded = await ShiftPresetPreferences.load();
    expect(loaded.map((preset) => preset.id), [
      'shift_late',
      'shift_early',
      'shift_middle',
    ]);
    expect(loaded.map((preset) => preset.order), [0, 1, 2]);
  });

  test('allows overnight times and rejects equal start and end times', () {
    expect(
      ShiftPresetPreferences.isValidEditablePreset(
        name: 'NIGHT',
        startTime: '22:00',
        endTime: '06:00',
        existing: const [],
      ),
      isTrue,
    );
    expect(
      ShiftPresetPreferences.isValidEditablePreset(
        name: 'INVALID',
        startTime: '07:00',
        endTime: '07:00',
        existing: const [],
      ),
      isFalse,
    );
  });

  test(
    'falls back safely for malformed or corrupt stored preferences',
    () async {
      SharedPreferences.setMockInitialValues({
        'shift_presets_v1': jsonEncode([
          {
            'id': 'bad',
            'name': '',
            'startTime': '25:00',
            'endTime': '10:00',
            'breakTime': '01:00',
            'order': 0,
          },
        ]),
      });

      expect((await ShiftPresetPreferences.load()).length, 3);
    },
  );
}
