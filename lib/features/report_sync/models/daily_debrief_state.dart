import 'package:flutter/foundation.dart';

typedef DailyDebriefChange = ({int revision, String operationDate});

final ValueNotifier<DailyDebriefChange> dailyDebriefRevisionNotifier =
    ValueNotifier<DailyDebriefChange>((revision: 0, operationDate: ''));

void notifyDailyDebriefChanged(String operationDate) {
  final current = dailyDebriefRevisionNotifier.value;
  dailyDebriefRevisionNotifier.value = (
    revision: current.revision + 1,
    operationDate: operationDate,
  );
}
