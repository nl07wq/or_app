import '../models/equipment.dart';

const builtInEquipment = <Equipment>[
  Equipment(
    id: 'power_rack',
    displayName: 'Power Rack',
    category: EquipmentCategory.rack,
  ),
  Equipment(
    id: 'bench_press_rack',
    displayName: 'Bench Press Rack',
    category: EquipmentCategory.rack,
  ),
  Equipment(
    id: 'smith_machine',
    displayName: 'Smith Machine',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'hammer_strength_bench',
    displayName: 'Hammer Strength Bench',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'hammer_strength_power_rack',
    displayName: 'Hammer Strength Power Rack',
    category: EquipmentCategory.rack,
  ),
  Equipment(
    id: 'leg_press_45',
    displayName: '45° Leg Press',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'horizontal_leg_press',
    displayName: 'Horizontal Leg Press',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'plate_loaded_leg_press',
    displayName: 'Plate Loaded Leg Press',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'linear_leg_press',
    displayName: 'Linear Leg Press',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'squat_press',
    displayName: 'Squat Press',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'nautilus_plate_loaded',
    displayName: 'Nautilus Plate Loaded',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'cybex_squat_press',
    displayName: 'Cybex Squat Press',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'lat_pulldown',
    displayName: 'Lat Pulldown',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'hammer_strength_lat_pulldown',
    displayName: 'Hammer Strength Lat Pulldown',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'technogym_lat_pulldown',
    displayName: 'Technogym Lat Pulldown',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'life_fitness_lat_pulldown',
    displayName: 'Life Fitness Lat Pulldown',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'cable_machine',
    displayName: 'Cable Machine',
    category: EquipmentCategory.cable,
  ),
  Equipment(
    id: 'cable_station',
    displayName: 'Cable Station',
    category: EquipmentCategory.cable,
  ),
  Equipment(
    id: 'hack_squat_machine',
    displayName: 'Hack Squat Machine',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'shoulder_press_machine',
    displayName: 'Shoulder Press Machine',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'incline_bench_machine',
    displayName: 'Incline Bench Machine',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'chest_press_machine',
    displayName: 'Chest Press Machine',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'seated_row_machine',
    displayName: 'Seated Row Machine',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'leg_curl_machine',
    displayName: 'Leg Curl Machine',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'dumbbells',
    displayName: 'Dumbbells',
    category: EquipmentCategory.freeWeight,
  ),
];

Equipment? equipmentById(String? id) {
  if (id == null) return null;
  for (final equipment in builtInEquipment) {
    if (equipment.id == id) return equipment;
  }
  return null;
}

String? canonicalEquipmentId({String? catalogId, required String name}) {
  final normalizedId = catalogId?.trim().toLowerCase();
  if (normalizedId != null && normalizedId.isNotEmpty) return normalizedId;
  final normalizedName = _normalizeEquipmentName(name);
  final aliasId = _canonicalEquipmentAliases[normalizedName];
  if (aliasId != null) return aliasId;
  for (final equipment in builtInEquipment) {
    if (_normalizeEquipmentName(equipment.displayName) == normalizedName) {
      return equipment.id;
    }
  }
  return null;
}

String canonicalEquipmentIdentityKey({
  String? catalogId,
  required String name,
}) {
  final canonicalId = canonicalEquipmentId(catalogId: catalogId, name: name);
  return canonicalId == null
      ? 'name:${_normalizeEquipmentName(name)}'
      : 'catalog:$canonicalId';
}

String equipmentDisplayNameJa(Equipment equipment) {
  return switch (equipment.id) {
    'power_rack' => 'パワーラック',
    'bench_press_rack' => 'ベンチプレスラック',
    'smith_machine' => 'スミスマシン',
    'hammer_strength_bench' => 'HAMMER STRENGTH ベンチ',
    'hammer_strength_power_rack' => 'HAMMER STRENGTH パワーラック',
    'leg_press_45' => '45°レッグプレス',
    'horizontal_leg_press' => 'ホリゾンタルレッグプレス',
    'plate_loaded_leg_press' => 'プレートロード・レッグプレス',
    'linear_leg_press' => 'リニアレッグプレス',
    'squat_press' => 'スクワットプレス',
    'nautilus_plate_loaded' => 'NAUTILUS プレートロード',
    'cybex_squat_press' => 'CYBEX スクワットプレス',
    'lat_pulldown' => 'ラットプルダウン',
    'hammer_strength_lat_pulldown' => 'HAMMER STRENGTH ラットプルダウン',
    'technogym_lat_pulldown' => 'TECHNOGYM ラットプルダウン',
    'life_fitness_lat_pulldown' => 'LIFE FITNESS ラットプルダウン',
    'cable_machine' => 'ケーブルマシン',
    'cable_station' => 'ケーブルステーション',
    'hack_squat_machine' => 'ハックスクワットマシン',
    'shoulder_press_machine' => 'ショルダープレスマシン',
    'incline_bench_machine' => 'インクラインベンチマシン',
    'chest_press_machine' => 'チェストプレスマシン',
    'seated_row_machine' => 'シーテッドロウマシン',
    'leg_curl_machine' => 'レッグカールマシン',
    'dumbbells' => 'ダンベル',
    _ => equipment.displayName,
  };
}

const _canonicalEquipmentAliases = <String, String>{
  'ハンマーストレングス ベンチ': 'hammer_strength_bench',
  'ハンマーストレングス・ベンチ': 'hammer_strength_bench',
  'hammer strength ベンチ': 'hammer_strength_bench',
  'hammer strength power rack': 'hammer_strength_power_rack',
  'hammer strength パワーラック': 'hammer_strength_power_rack',
  'hammer strength lat pull': 'hammer_strength_lat_pulldown',
  'hammer strength lat pulldown': 'hammer_strength_lat_pulldown',
  'hammer strength ラットプルダウン': 'hammer_strength_lat_pulldown',
  'nautilus plate loaded': 'nautilus_plate_loaded',
  'nautilus プレートロード': 'nautilus_plate_loaded',
  'cybex squat press': 'cybex_squat_press',
  'cybex スクワットプレス': 'cybex_squat_press',
  'テクノジム・ラットプルダウン': 'technogym_lat_pulldown',
  'technogym ラットプルダウン': 'technogym_lat_pulldown',
  'ライフフィットネス・ラットプルダウン': 'life_fitness_lat_pulldown',
  'life fitness ラットプルダウン': 'life_fitness_lat_pulldown',
};

String _normalizeEquipmentName(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
