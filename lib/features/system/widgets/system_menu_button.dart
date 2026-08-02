import 'package:flutter/material.dart';

import '../../../core/navigation/app_routes.dart';

enum _SystemMenuDestination { profile, settings, system }

class SystemMenuButton extends StatelessWidget {
  const SystemMenuButton({super.key});

  @override
  Widget build(BuildContext context) => PopupMenuButton<_SystemMenuDestination>(
    icon: const Icon(Icons.more_horiz),
    tooltip: 'SYSTEM MENU',
    onSelected: (destination) {
      final route = switch (destination) {
        _SystemMenuDestination.profile => AppRoutes.profile,
        _SystemMenuDestination.settings => AppRoutes.settings,
        _SystemMenuDestination.system => AppRoutes.system,
      };
      Navigator.pushNamed(context, route);
    },
    itemBuilder: (_) => const [
      PopupMenuItem(
        value: _SystemMenuDestination.profile,
        child: Text('PROFILE'),
      ),
      PopupMenuItem(
        value: _SystemMenuDestination.settings,
        child: Text('SETTINGS'),
      ),
      PopupMenuItem(
        value: _SystemMenuDestination.system,
        child: Text('SYSTEM'),
      ),
    ],
  );
}
