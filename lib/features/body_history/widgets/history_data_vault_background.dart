import 'package:flutter/material.dart';

import 'history_data_vault_hyperspace.dart';

class HistoryDataVaultBackground extends StatelessWidget {
  const HistoryDataVaultBackground({super.key, this.seconds = 0});

  final double seconds;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      key: const ValueKey('history-data-vault-background'),
      painter: _HistoryDataVaultPainter(seconds),
      size: Size.infinite,
    ),
  );
}

class _HistoryDataVaultPainter extends CustomPainter {
  const _HistoryDataVaultPainter(this.seconds);
  final double seconds;
  @override
  void paint(Canvas canvas, Size size) =>
      HistoryDataVaultHyperspace(seconds: seconds).paint(canvas, size);
  @override
  bool shouldRepaint(_HistoryDataVaultPainter oldDelegate) =>
      oldDelegate.seconds != seconds;
}
