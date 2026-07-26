import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/repositories/repository_exception.dart';

void main() {
  test('repository errors expose a machine-readable error code', () {
    const exception = RepositoryException(
      operation: 'migration.verify',
      code: RepositoryErrorCode.verificationFailed,
      cause: FormatException('record IDs differ'),
    );

    expect(exception.operation, 'migration.verify');
    expect(exception.code, RepositoryErrorCode.verificationFailed);
    expect(exception.cause, isA<FormatException>());
    expect(exception.toString(), contains('verificationFailed'));
  });

  test('existing callers default to the unknown error code', () {
    final exception = RepositoryException(
      operation: 'training.findAll',
      cause: StateError('failed'),
    );

    expect(exception.code, RepositoryErrorCode.unknown);
  });
}
