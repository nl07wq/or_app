import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/operation_text_field.dart';

class MemoInputCard extends StatefulWidget {
  final TextEditingController controller;

  const MemoInputCard({super.key, required this.controller});

  @override
  State<MemoInputCard> createState() => _MemoInputCardState();
}

class _MemoInputCardState extends State<MemoInputCard> {
  bool expanded = true;

  void collapse() {
    FocusManager.instance.primaryFocus?.unfocus();

    if (!mounted) return;

    setState(() {
      expanded = false;
    });
  }

  void expand() {
    if (!mounted) return;

    setState(() {
      expanded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return OperationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(icon: Icons.edit_note, title: "MEMO"),

          const SizedBox(height: 20),

          if (!expanded)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: expand,
                child: Text(
                  widget.controller.text.isEmpty
                      ? "No Memo"
                      : widget.controller.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.lightBlueAccent,
                  ),
                ),
              ),
            ),

          if (expanded) ...[
            OperationTextField(
              controller: widget.controller,
              label: "Memo",
              maxLines: 4,
            ),

            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: collapse, child: const Text("完了")),
            ),
          ],
        ],
      ),
    );
  }
}
