import 'package:flutter/material.dart';

import '../../../core/models/training_equipment_snapshot.dart';
import '../models/training_record_read_model.dart';
import '../services/equipment_catalog.dart';

class TrainingEquipmentCandidates {
  final List<TrainingEquipmentSnapshot> values;

  const TrainingEquipmentCandidates._(this.values);

  factory TrainingEquipmentCandidates.fromRecords(
    Iterable<TrainingRecordReadModel> records,
  ) {
    final candidates = <TrainingEquipmentSnapshot>[
      for (final value in builtInEquipment)
        TrainingEquipmentSnapshot(catalogId: value.id, name: value.displayName),
    ];
    for (final record in records) {
      final v2 = record.v2Data;
      if (v2 != null) {
        candidates.addAll(
          v2.exercises.map((exercise) => exercise.equipment).nonNulls,
        );
        candidates.addAll(
          v2.cardioEntries.map((entry) => entry.equipment).nonNulls,
        );
      }
      final v1 = record.v1Data;
      if (v1 != null) {
        for (final exercise in v1.exercises) {
          final catalog = equipmentById(exercise.equipmentId);
          if (catalog != null) {
            candidates.add(
              TrainingEquipmentSnapshot(
                catalogId: catalog.id,
                name: catalog.displayName,
              ),
            );
          }
        }
      }
    }
    final seen = <String>{};
    return TrainingEquipmentCandidates._(
      List.unmodifiable(
        candidates.where((value) {
          final key = value.catalogId == null
              ? 'name:${_normalize(value.name)}'
              : 'catalog:${_normalize(value.catalogId!)}';
          return seen.add(key);
        }),
      ),
    );
  }
}

class TrainingEquipmentField extends StatelessWidget {
  final TrainingEquipmentSnapshot? value;
  final TrainingEquipmentCandidates candidates;
  final ValueChanged<TrainingEquipmentSnapshot?> onChanged;
  final String fieldKey;

  const TrainingEquipmentField({
    super.key,
    required this.value,
    required this.candidates,
    required this.onChanged,
    required this.fieldKey,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key(fieldKey),
      onTap: () => _select(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Equipment',
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        isEmpty: value == null,
        child: Text(value?.name ?? 'None'),
      ),
    );
  }

  Future<void> _select(BuildContext context) async {
    final selected = await showModalBottomSheet<_EquipmentSelection>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EquipmentSheet(candidates: candidates.values),
    );
    if (selected == null) return;
    onChanged(selected.value);
  }
}

class _EquipmentSheet extends StatelessWidget {
  final List<TrainingEquipmentSnapshot> candidates;

  const _EquipmentSheet({required this.candidates});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: const Text('None'),
                    onTap: () =>
                        Navigator.pop(context, const _EquipmentSelection(null)),
                  ),
                  for (final candidate in candidates)
                    ListTile(
                      leading: const Icon(Icons.fitness_center_outlined),
                      title: Text(candidate.name),
                      subtitle: candidate.catalogId == null
                          ? const Text('Saved / custom')
                          : null,
                      onTap: () => Navigator.pop(
                        context,
                        _EquipmentSelection(candidate),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Custom Equipment'),
              onTap: () => _custom(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _custom(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Equipment'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Equipment Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (name == null || !context.mounted) return;
    Navigator.pop(
      context,
      _EquipmentSelection(TrainingEquipmentSnapshot(name: name)),
    );
  }
}

class _EquipmentSelection {
  final TrainingEquipmentSnapshot? value;

  const _EquipmentSelection(this.value);
}

String _normalize(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
