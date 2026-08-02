import 'package:flutter/material.dart';

import '../../../core/navigation/app_routes.dart';

enum _SystemMenuDestination { profile, settings, system }

class SystemMenuButton extends StatelessWidget {
  const SystemMenuButton({super.key});

  @override
  Widget build(BuildContext context) => PopupMenuButton<_SystemMenuDestination>(
    icon: const Icon(Icons.more_vert),
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
        child: ListTile(
          leading: Icon(Icons.account_circle),
          contentPadding: EdgeInsets.zero,
          title: Text('PROFILE'),
        ),
      ),
      PopupMenuItem(
        value: _SystemMenuDestination.settings,
        child: ListTile(
          leading: Icon(Icons.settings),
          contentPadding: EdgeInsets.zero,
          title: Text('SETTINGS'),
        ),
      ),
      PopupMenuItem(
        value: _SystemMenuDestination.system,
        child: ListTile(
          leading: Icon(Icons.admin_panel_settings),
          contentPadding: EdgeInsets.zero,
          title: Text('SYSTEM'),
        ),
      ),
    ],
  );
}
