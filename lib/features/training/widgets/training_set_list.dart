import 'package:flutter/material.dart';

import '../models/training_set_controller.dart';
import 'training_set_row.dart';

class TrainingSetList extends StatefulWidget {
  final List<TrainingSetController> sets;
  final bool isEditMode;
  final Function(int) onDelete;
  final Function(int) onCopy;

  const TrainingSetList({
    super.key,
    required this.sets,
    required this.isEditMode,
    required this.onCopy,
    required this.onDelete,
  });

  @override
  State<TrainingSetList> createState() => _TrainingSetListState();
}

class _TrainingSetListState extends State<TrainingSetList> {
  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,

      itemCount: widget.sets.length,

      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex--;
          }

          final item = widget.sets.removeAt(oldIndex);
          widget.sets.insert(newIndex, item);
        });
      },

      itemBuilder: (context, index) {
        final set = widget.sets[index];

        return Padding(
          key: ValueKey(set),
          padding: const EdgeInsets.only(bottom: 16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Text(
                    'SET ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index > 0) ...[
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.monitor_weight_outlined),
                          tooltip: 'Copy previous weight',
                          onPressed: () => _copyText(
                            widget.sets[index - 1].weightController,
                            set.weightController,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.repeat),
                          tooltip: 'Copy previous reps',
                          onPressed: () => _copyText(
                            widget.sets[index - 1].repsController,
                            set.repsController,
                          ),
                        ),
                      ],
                      if (widget.isEditMode)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.copy_outlined),
                          tooltip: 'Copy Set',
                          onPressed: () {
                            widget.onCopy(index);
                          },
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        tooltip: 'Delete set',
                        onPressed: widget.sets.length > 1
                            ? () {
                                widget.onDelete(index);
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),

              TrainingSetRow(
                setNo: index + 1,
                weightController: set.weightController,
                repsController: set.repsController,
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyText(
    TextEditingController source,
    TextEditingController destination,
  ) {
    final text = source.text;
    destination.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
