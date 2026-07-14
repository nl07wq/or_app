import 'package:flutter/material.dart';

class OperationInputContainer extends StatefulWidget {
  final String title;
  final TextEditingController controller;
  final Widget child;
  final bool initiallyExpanded;
  final VoidCallback? onCompleted;

  final bool autoCollapse;

  final String? suffix;

  const OperationInputContainer({
    super.key,
    required this.title,
    required this.controller,
    required this.child,
    this.initiallyExpanded = true,
    this.onCompleted,
    this.autoCollapse = false,
    this.suffix,
  });

  @override
  State<OperationInputContainer> createState() =>
      _OperationInputContainerState();
}

class _OperationInputContainerState extends State<OperationInputContainer> {
  late bool expanded;

  void collapse() {
    if (!mounted) return;

    widget.onCompleted?.call();

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
  void initState() {
    super.initState();
    expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                if (!expanded && value.text.isNotEmpty)
                  TextButton(
                    onPressed: expand,
                    child: Text(
                      widget.suffix == null
                          ? value.text
                          : "${value.text} ${widget.suffix}",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.lightBlueAccent,
                      ),
                    ),
                  ),
              ],
            ),

            if (expanded) ...[
              widget.child,

              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: collapse,
                  child: const Text("完了"),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
