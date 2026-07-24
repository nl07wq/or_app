enum EquipmentCategory { rack, machine, cable }

class Equipment {
  final String id;
  final String displayName;
  final EquipmentCategory category;

  const Equipment({
    required this.id,
    required this.displayName,
    required this.category,
  });
}
