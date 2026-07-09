class CommanderMessage {
  final String title;
  final String message;
  final List<String> recommendations;

  const CommanderMessage({
    required this.title,
    required this.message,
    this.recommendations = const [],
  });
}
