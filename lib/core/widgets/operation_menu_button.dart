import 'package:flutter/material.dart';

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
    return PopupMenuButton<OperationMenuItem>(
      icon: const Icon(Icons.more_vert),
      onSelected: (item) {
        item.onTap();
      },
      itemBuilder: (_) {
        return items.map((item) {
          return PopupMenuItem<OperationMenuItem>(
            value: item,
            child: Row(
              children: [
                Icon(item.icon, size: 20),
                const SizedBox(width: 12),
                Text(item.title),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}
