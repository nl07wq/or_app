import '../models/equipment.dart';
import 'equipment_catalog.dart';
import 'exercise_name_localization.dart';

const _equipmentIdsByExercise = <String, List<String>>{
  'benchpress': [
    'power_rack',
    'bench_press_rack',
    'smith_machine',
    'hammer_strength_bench',
  ],
  'latpulldown': [
    'technogym_lat_pulldown',
    'life_fitness_lat_pulldown',
    'lat_pulldown',
    'cable_station',
    'cable_machine',
  ],
  'legpress': [
    'leg_press_45',
    'linear_leg_press',
    'squat_press',
    'horizontal_leg_press',
    'plate_loaded_leg_press',
  ],
  'shoulderpress': [
    'shoulder_press_machine',
    'smith_machine',
    'cable_station',
    'dumbbells',
  ],
  'inclinebenchpress': [
    'incline_bench_machine',
    'power_rack',
    'smith_machine',
    'dumbbells',
  ],
  'chestpress': [
    'chest_press_machine',
    'hammer_strength_bench',
    'cable_station',
  ],
  'seatedrow': ['seated_row_machine', 'cable_station', 'cable_machine'],
  'dumbbellcurl': ['dumbbells'],
  'squat': ['power_rack', 'smith_machine'],
  'legcurl': ['leg_curl_machine'],
  'hacksquat': ['hack_squat_machine'],
};

List<String> compatibleEquipmentIds(String exerciseName) {
  final ids = _equipmentIdsByExercise[exerciseIdentityKey(exerciseName)];
  return ids == null ? const [] : List.unmodifiable(ids);
}

List<Equipment> compatibleEquipment(String exerciseName) {
  return compatibleEquipmentIds(
    exerciseName,
  ).map(equipmentById).whereType<Equipment>().toList(growable: false);
}
