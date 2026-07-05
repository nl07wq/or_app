import 'package:flutter/material.dart';

Future<bool> showHistoryDeleteDialog(
  BuildContext context, {
  required String title,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('$titleを削除'),
        content: Text(
          'この$titleを削除しますか？\n\n'
          'この操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('削除'),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
