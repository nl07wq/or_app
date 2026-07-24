import '../models/equipment.dart';

const builtInEquipment = <Equipment>[
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
    id: 'lat_pulldown',
    displayName: 'Lat Pulldown',
    category: EquipmentCategory.machine,
  ),
  Equipment(
    id: 'cable_machine',
    displayName: 'Cable Machine',
    category: EquipmentCategory.cable,
  ),
  Equipment(
    id: 'hack_squat_machine',
    displayName: 'Hack Squat Machine',
    category: EquipmentCategory.machine,
  ),
];

Equipment? equipmentById(String? id) {
  if (id == null) return null;
  for (final equipment in builtInEquipment) {
    if (equipment.id == id) return equipment;
  }
  return null;
}
