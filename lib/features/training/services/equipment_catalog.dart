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
    id: 'lat_pulldown',
    displayName: 'Lat Pulldown',
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

String equipmentDisplayNameJa(Equipment equipment) {
  return switch (equipment.id) {
    'power_rack' => 'パワーラック',
    'bench_press_rack' => 'ベンチプレスラック',
    'smith_machine' => 'スミスマシン',
    'hammer_strength_bench' => 'ハンマーストレングス・ベンチ',
    'leg_press_45' => '45°レッグプレス',
    'horizontal_leg_press' => 'ホリゾンタルレッグプレス',
    'plate_loaded_leg_press' => 'プレートロード・レッグプレス',
    'linear_leg_press' => 'リニアレッグプレス',
    'squat_press' => 'スクワットプレス',
    'lat_pulldown' => 'ラットプルダウン',
    'technogym_lat_pulldown' => 'テクノジム・ラットプルダウン',
    'life_fitness_lat_pulldown' => 'ライフフィットネス・ラットプルダウン',
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
