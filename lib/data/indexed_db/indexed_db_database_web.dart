// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'indexed_db_database_contract.dart';
import 'indexed_db_schema.dart';

Future<IndexedDbDatabase> createIndexedDbDatabase() async {
  final factory = html.window.indexedDB;
  if (factory == null) {
    throw UnsupportedError('IndexedDB is not supported by this browser.');
  }

  final database = await factory.open(
    IndexedDbSchema.databaseName,
    version: IndexedDbSchema.databaseVersion,
    onUpgradeNeeded: (event) {
      final request = event.target as dynamic;
      final database = request.result as dynamic;
      final existingStores = database.objectStoreNames ?? const <String>[];
      final transaction = request.transaction as dynamic;
      for (final definition in IndexedDbSchema.storeDefinitions) {
        final dynamic store;
        if (!existingStores.contains(definition.name)) {
          store = database.createObjectStore(
            definition.name,
            keyPath: definition.keyPath,
          );
        } else {
          store = transaction.objectStore(definition.name);
        }

        final existingIndexes = store.indexNames ?? const <String>[];
        for (final index in definition.indexes) {
          if (!existingIndexes.contains(index.name)) {
            store.createIndex(
              index.name,
              index.keyPath,
              unique: index.unique,
              multiEntry: index.multiEntry,
            );
          }
        }
      }
    },
  );

  return _WebIndexedDbDatabase(database);
}

class _WebIndexedDbDatabase implements IndexedDbDatabase {
  final dynamic _database;

  const _WebIndexedDbDatabase(this._database);

  @override
  Future<void> put(String storeName, Map<String, Object?> record) {
    return _write(storeName, (store) async {
      await store.put(record);
    });
  }

  @override
  Future<Map<String, Object?>?> findById(String storeName, String id) async {
    return _read(storeName, (store) async {
      final value = await store.getObject(id);
      if (value == null) return null;
      return Map<String, Object?>.from(value as Map);
    });
  }

  @override
  Future<List<Map<String, Object?>>> findAll(String storeName) {
    return _read(storeName, (store) async {
      final request = store.getAll(null);
      final value = await _completeRequest(request);
      return [
        for (final record in value as List)
          Map<String, Object?>.from(record as Map),
      ];
    });
  }

  @override
  Future<void> deleteById(String storeName, String id) {
    return _write(storeName, (store) async {
      await store.delete(id);
    });
  }

  @override
  Future<void> clear(String storeName) {
    return _write(storeName, (store) async {
      await store.clear();
    });
  }

  Future<T> _read<T>(
    String storeName,
    Future<T> Function(dynamic store) operation,
  ) {
    return _transaction(storeName, 'readonly', operation);
  }

  Future<T> _write<T>(
    String storeName,
    Future<T> Function(dynamic store) operation,
  ) {
    return _transaction(storeName, 'readwrite', operation);
  }

  Future<T> _transaction<T>(
    String storeName,
    String mode,
    Future<T> Function(dynamic store) operation,
  ) async {
    final transaction = _database.transaction(storeName, mode);
    final completed = transaction.completed;
    try {
      final store = transaction.objectStore(storeName);
      if (store == null) {
        throw StateError('IndexedDB object store is unavailable: $storeName');
      }
      final result = await operation(store);
      await completed;
      return result;
    } catch (_) {
      try {
        transaction.abort();
      } catch (_) {
        // The browser may have already completed or aborted the transaction.
      }
      rethrow;
    }
  }

  Future<Object?> _completeRequest(dynamic request) {
    final completer = Completer<Object?>();
    request.onSuccess.first.then((_) {
      if (!completer.isCompleted) completer.complete(request.result);
    });
    request.onError.first.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          request.error ?? StateError('IndexedDB request failed.'),
        );
      }
    });
    return completer.future;
  }
}
