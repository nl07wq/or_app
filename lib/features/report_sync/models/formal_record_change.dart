import 'package:flutter/foundation.dart';

enum FormalRecordKind { dailyBrief, dailyDebrief }

typedef FormalRecordChange = ({
  int revision,
  String operationDate,
  FormalRecordKind kind,
});

final ValueNotifier<FormalRecordChange> formalRecordChangeNotifier =
    ValueNotifier<FormalRecordChange>((
      revision: 0,
      operationDate: '',
      kind: FormalRecordKind.dailyBrief,
    ));

void notifyFormalRecordChanged({
  required String operationDate,
  required FormalRecordKind kind,
}) {
  final current = formalRecordChangeNotifier.value;
  formalRecordChangeNotifier.value = (
    revision: current.revision + 1,
    operationDate: operationDate,
    kind: kind,
  );
}
