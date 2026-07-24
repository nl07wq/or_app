import 'package:flutter/material.dart';

import '../services/equipment_catalog.dart';

class EquipmentSelector extends StatelessWidget {
  final ValueNotifier<String?> controller;

  const EquipmentSelector({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: controller,
      builder: (context, equipmentId, _) {
        final equipment = equipmentById(equipmentId);
        return InkWell(
          key: const Key('equipment-selector'),
          onTap: () => _openSelector(context),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Equipment',
              suffixIcon: Icon(Icons.arrow_drop_down),
              constraints: BoxConstraints(minHeight: 56),
            ),
            child: Text(equipment?.displayName ?? 'None'),
          ),
        );
      },
    );
  }

  Future<void> _openSelector(BuildContext context) async {
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => const _EquipmentPickerSheet(),
    );
    if (selectedId == null) return;
    controller.value = selectedId.isEmpty ? null : selectedId;
  }
}

class _EquipmentPickerSheet extends StatelessWidget {
  const _EquipmentPickerSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('None'),
            onTap: () => Navigator.pop(context, ''),
          ),
          const Divider(height: 1),
          for (final equipment in builtInEquipment)
            ListTile(
              title: Text(equipment.displayName),
              onTap: () => Navigator.pop(context, equipment.id),
            ),
        ],
      ),
    );
  }
}
