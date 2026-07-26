import '../../features/repositories/app_repository_container.dart';
import '../../features/repositories/repository_exception.dart';
import '../state/app_initialization_state.dart';

abstract final class PersistenceAccess {
  static bool get usesCompatibilityStorage =>
      !AppRepositoryRegistry.startupManaged;

  static bool get canReadIndexedDb =>
      AppRepositoryRegistry.hasContainer &&
      (AppRepositoryRegistry.controller.value.mode ==
              PersistenceMode.indexedDbReadWrite ||
          AppRepositoryRegistry.controller.value.mode ==
              PersistenceMode.initializing);

  static void requireWrite(String operation) {
    if (usesCompatibilityStorage) return;
    if (AppRepositoryRegistry.controller.value.mode !=
        PersistenceMode.indexedDbReadWrite) {
      throw RepositoryException(
        operation: operation,
        code: RepositoryErrorCode.transactionFailed,
        cause: StateError(
          'Persistence is ${AppRepositoryRegistry.controller.value.mode.name}.',
        ),
      );
    }
  }

  static void requireReadable(String operation) {
    if (usesCompatibilityStorage ||
        canReadIndexedDb ||
        AppRepositoryRegistry.controller.value.mode ==
            PersistenceMode.legacyReadOnly) {
      return;
    }
    throw RepositoryException(
      operation: operation,
      cause: StateError(
        'Persistence is ${AppRepositoryRegistry.controller.value.mode.name}.',
      ),
    );
  }
}
