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

                  if (widget.isEditMode)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy_outlined),
                          tooltip: 'Copy Set',
                          onPressed: () {
                            widget.onCopy(index);
                          },
                        ),

                        if (widget.sets.length > 1)
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            onPressed: () {
                              widget.onDelete(index);
                            },
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
}
