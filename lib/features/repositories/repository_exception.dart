class RepositoryException implements Exception {
  final String operation;
  final Object cause;

  const RepositoryException({required this.operation, required this.cause});

  @override
  String toString() => 'RepositoryException($operation): $cause';
}
