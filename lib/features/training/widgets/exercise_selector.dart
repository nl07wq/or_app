import 'package:flutter/material.dart';

import '../services/exercise_catalog_service.dart';

class ExerciseSelector extends StatelessWidget {
  final TextEditingController controller;

  const ExerciseSelector({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final selectedName = value.text.trim();
        return InkWell(
          key: const Key('exercise-selector'),
          onTap: () => _openSelector(context),
          child: InputDecorator(
            isEmpty: selectedName.isEmpty,
            decoration: const InputDecoration(
              labelText: 'Exercise',
              suffixIcon: Icon(Icons.arrow_drop_down),
              constraints: BoxConstraints(minHeight: 56),
            ),
            child: Text(
              selectedName.isEmpty ? 'Select exercise' : selectedName,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSelector(BuildContext context) async {
    final catalog = await ExerciseCatalogService.load();
    if (!context.mounted) return;

    final selectedName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ExercisePickerSheet(catalog: catalog),
    );
    if (selectedName == null) return;

    controller.text = selectedName;
  }
}

class _ExercisePickerSheet extends StatelessWidget {
  final ExerciseCatalog catalog;

  const _ExercisePickerSheet({required this.catalog});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  if (catalog.recent.isNotEmpty) ...[
                    const _SectionLabel('Recent'),
                    ...catalog.recent.map(
                      (name) => ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(name),
                        onTap: () => Navigator.pop(context, name),
                      ),
                    ),
                    const Divider(),
                  ],
                  const _SectionLabel('All Exercises'),
                  ...catalog.all.map(
                    (name) => ListTile(
                      title: Text(name),
                      onTap: () => Navigator.pop(context, name),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add Custom Exercise'),
              onTap: () => _addCustomExercise(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addCustomExercise(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AddCustomExerciseDialog(),
    );
    if (name == null) return;

    if (context.mounted) Navigator.pop(context, name);
  }
}

class _AddCustomExerciseDialog extends StatefulWidget {
  const _AddCustomExerciseDialog();

  @override
  State<_AddCustomExerciseDialog> createState() =>
      _AddCustomExerciseDialogState();
}

class _AddCustomExerciseDialogState extends State<_AddCustomExerciseDialog> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Custom Exercise'),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Exercise name'),
        textCapitalization: TextCapitalization.words,
        onChanged: (_) => setState(() {}),
        onSubmitted: (value) => _registerAndClose(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _nameController.text.trim().isEmpty
              ? null
              : () => _registerAndClose(_nameController.text),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _registerAndClose(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    await ExerciseCatalogService.registerCustom(trimmedName);
    if (mounted) Navigator.pop(context, trimmedName);
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
