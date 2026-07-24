enum EquipmentCategory { rack, machine, cable, freeWeight }

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
