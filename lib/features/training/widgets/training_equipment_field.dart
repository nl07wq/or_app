import 'package:flutter/material.dart';

import '../../../core/models/training_equipment_snapshot.dart';
import '../services/training_equipment_candidates.dart';

class TrainingEquipmentField extends StatelessWidget {
  final TrainingEquipmentSnapshot? value;
  final TrainingEquipmentCandidates candidates;
  final ValueChanged<TrainingEquipmentSnapshot?> onChanged;
  final String fieldKey;
  final bool hasSelection;
  final bool allowCustom;

  const TrainingEquipmentField({
    super.key,
    required this.value,
    required this.candidates,
    required this.onChanged,
    required this.fieldKey,
    this.hasSelection = true,
    this.allowCustom = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key(fieldKey),
      onTap: () => _select(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: hasSelection ? 'Equipment' : null,
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        isEmpty: !hasSelection,
        child: Text(
          !hasSelection
              ? 'Equipment'
              : value == null
              ? 'なし'
              : trainingEquipmentDisplayLabel(value!),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _select(BuildContext context) async {
    final selected = await showModalBottomSheet<_EquipmentSelection>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EquipmentSheet(
        candidates: candidates.values,
        allowCustom: allowCustom,
      ),
    );
    if (selected == null) return;
    onChanged(selected.value);
  }
}

class _EquipmentSheet extends StatelessWidget {
  final List<TrainingEquipmentSnapshot> candidates;
  final bool allowCustom;

  const _EquipmentSheet({required this.candidates, required this.allowCustom});

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
                    title: const Text('なし'),
                    onTap: () =>
                        Navigator.pop(context, const _EquipmentSelection(null)),
                  ),
                  for (final candidate in candidates)
                    ListTile(
                      leading: const Icon(Icons.fitness_center_outlined),
                      title: Text(trainingEquipmentDisplayLabel(candidate)),
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
            if (allowCustom) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Custom Equipment'),
                onTap: () => _custom(context),
              ),
            ],
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
