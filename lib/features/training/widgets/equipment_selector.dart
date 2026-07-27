import 'package:flutter/material.dart';

import '../models/equipment.dart';
import '../services/equipment_catalog.dart';
import '../services/exercise_equipment_mapping.dart';

class EquipmentSelector extends StatefulWidget {
  final TextEditingController exerciseController;
  final ValueNotifier<String?> controller;

  const EquipmentSelector({
    super.key,
    required this.exerciseController,
    required this.controller,
  });

  @override
  State<EquipmentSelector> createState() => _EquipmentSelectorState();
}

class _EquipmentSelectorState extends State<EquipmentSelector> {
  @override
  void initState() {
    super.initState();
    widget.exerciseController.addListener(_handleExerciseChanged);
    _resetInvalidEquipment();
  }

  @override
  void didUpdateWidget(covariant EquipmentSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.exerciseController, widget.exerciseController)) {
      oldWidget.exerciseController.removeListener(_handleExerciseChanged);
      widget.exerciseController.addListener(_handleExerciseChanged);
    }
    _resetInvalidEquipment();
  }

  @override
  void dispose() {
    widget.exerciseController.removeListener(_handleExerciseChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.exerciseController,
      builder: (context, exerciseValue, _) {
        final equipment = compatibleEquipment(exerciseValue.text);
        return ValueListenableBuilder<String?>(
          valueListenable: widget.controller,
          builder: (context, equipmentId, _) {
            final selectedEquipment = equipmentById(equipmentId);
            final selectedName = selectedEquipment == null
                ? 'なし'
                : equipmentDisplayNameJa(selectedEquipment);
            return InkWell(
              key: const Key('equipment-selector'),
              onTap: () => _openSelector(context, equipment),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Equipment',
                  suffixIcon: Icon(Icons.arrow_drop_down),
                  constraints: BoxConstraints(minHeight: 56),
                ),
                child: Text(
                  selectedName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openSelector(
    BuildContext context,
    List<Equipment> equipment,
  ) async {
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => _EquipmentPickerSheet(equipment: equipment),
    );
    if (selectedId == null) return;
    widget.controller.value = selectedId.isEmpty ? null : selectedId;
  }

  void _handleExerciseChanged() {
    _resetInvalidEquipment();
  }

  void _resetInvalidEquipment() {
    final equipmentId = widget.controller.value;
    if (equipmentId == null) return;
    final validIds = compatibleEquipmentIds(widget.exerciseController.text);
    if (!validIds.contains(equipmentId)) {
      widget.controller.value = null;
    }
  }
}

class _EquipmentPickerSheet extends StatelessWidget {
  final List<Equipment> equipment;

  const _EquipmentPickerSheet({required this.equipment});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('なし'),
            onTap: () => Navigator.pop(context, ''),
          ),
          const Divider(height: 1),
          for (final item in equipment)
            ListTile(
              title: Text(equipmentDisplayNameJa(item)),
              onTap: () => Navigator.pop(context, item.id),
            ),
        ],
      ),
    );
  }
}
