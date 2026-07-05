enum WorkType {
  work("出勤"),
  holiday("公休日"),
  paidLeave("有給休暇"),
  halfDay("半休"),
  other("その他");

  const WorkType(this.label);

  final String label;
}
