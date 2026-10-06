import 'package:flutter/material.dart';

import '../global_touch_ripple.dart';

Future<bool> showHistoryDeleteDialog(
  BuildContext context, {
  required String title,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('この$titleを削除しますか？'),
        content: const Text('この操作は取り消せません。'),
        actions: [
          ActionableFeedbackButton(
            enabled: true,
            child: TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('キャンセル'),
            ),
          ),
          ActionableFeedbackButton(
            enabled: true,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('削除'),
            ),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
