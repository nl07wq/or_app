import 'package:flutter/material.dart';

import 'global_touch_ripple.dart';

class OperationMenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const OperationMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}

class OperationMenuButton extends StatelessWidget {
  final List<OperationMenuItem> items;

  const OperationMenuButton({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return ActionableFeedbackButton(
      enabled: true,
      child: PopupMenuButton<OperationMenuItem>(
        icon: const Icon(Icons.more_vert),
        onSelected: (item) {
          item.onTap();
        },
        itemBuilder: (_) => items
            .map(
              (item) => PopupMenuItem<OperationMenuItem>(
                value: item,
                child: ActionableFeedbackButton(
                  enabled: true,
                  child: Row(
                    children: [
                      Icon(item.icon, size: 20),
                      const SizedBox(width: 12),
                      Text(item.title),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
