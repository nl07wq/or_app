import 'package:flutter/foundation.dart';

final ValueNotifier<int> morningBriefRevisionNotifier = ValueNotifier<int>(0);

void notifyMorningBriefChanged() {
  morningBriefRevisionNotifier.value++;
}
