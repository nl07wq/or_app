enum WorkTemplate {
  early("早番", "07:00", "18:00", "01:00"),

  middle("中番", "11:00", "18:00", "01:00"),

  late("遅番", "15:15", "00:15", "01:00");

  const WorkTemplate(this.label, this.start, this.end, this.breakTime);

  final String label;
  final String start;
  final String end;
  final String breakTime;
}
