enum WorkType {
  work("出勤"),
  holiday("公休日"),
  paidLeave("有給休暇"),
  halfDay("半休"),
  other("その他");

  const WorkType(this.label);

  final String label;

  /// 勤務時間を計算・表示する勤務区分
  bool get isWorking {
    switch (this) {
      case WorkType.work:
      case WorkType.halfDay:
        return true;

      case WorkType.holiday:
      case WorkType.paidLeave:
      case WorkType.other:
        return false;
    }
  }
}
