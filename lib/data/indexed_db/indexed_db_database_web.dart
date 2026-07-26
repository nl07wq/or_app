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
    return runTransaction(
      storeNames: [storeName],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) async {
        await transaction.put(storeName, record);
      },
    );
  }

  @override
  Future<Map<String, Object?>?> findById(String storeName, String id) {
    return runTransaction(
      storeNames: [storeName],
      mode: IndexedDbTransactionMode.readOnly,
      action: (transaction) => transaction.findById(storeName, id),
    );
  }

  @override
  Future<List<Map<String, Object?>>> findAll(String storeName) {
    return runTransaction(
      storeNames: [storeName],
      mode: IndexedDbTransactionMode.readOnly,
      action: (transaction) => transaction.findAll(storeName),
    );
  }

  @override
  Future<void> deleteById(String storeName, String id) {
    return runTransaction(
      storeNames: [storeName],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) => transaction.deleteById(storeName, id),
    );
  }

  @override
  Future<void> clear(String storeName) {
    return runTransaction(
      storeNames: [storeName],
      mode: IndexedDbTransactionMode.readWrite,
      action: (transaction) => transaction.clear(storeName),
    );
  }

  @override
  Future<T> runTransaction<T>({
    required Iterable<String> storeNames,
    required IndexedDbTransactionMode mode,
    required Future<T> Function(IndexedDbTransaction transaction) action,
  }) async {
    final names = List<String>.unmodifiable(storeNames.toSet());
    if (names.isEmpty) {
      throw ArgumentError.value(
        storeNames,
        'storeNames',
        'At least one IndexedDB store is required.',
      );
    }
    final transaction = _database.transaction(
      names.length == 1 ? names.single : names,
      mode == IndexedDbTransactionMode.readOnly ? 'readonly' : 'readwrite',
    );
    final completed = transaction.completed;
    try {
      final result = await action(_WebIndexedDbTransaction(transaction, names));
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
}

class _WebIndexedDbTransaction implements IndexedDbTransaction {
  final dynamic _transaction;
  final Set<String> _storeNames;

  _WebIndexedDbTransaction(dynamic transaction, Iterable<String> storeNames)
    : _transaction = transaction,
      _storeNames = Set.unmodifiable(storeNames);

  @override
  Future<void> put(String storeName, Map<String, Object?> record) async {
    final store = _store(storeName);
    await store.put(record);
  }

  @override
  Future<Map<String, Object?>?> findById(String storeName, String id) async {
    final value = await _store(storeName).getObject(id);
    if (value == null) return null;
    return Map<String, Object?>.from(value as Map);
  }

  @override
  Future<List<Map<String, Object?>>> findAll(String storeName) async {
    final request = _store(storeName).getAll(null);
    final value = await _completeRequest(request);
    return [
      for (final record in value as List)
        Map<String, Object?>.from(record as Map),
    ];
  }

  @override
  Future<void> deleteById(String storeName, String id) async {
    await _store(storeName).delete(id);
  }

  @override
  Future<void> clear(String storeName) async {
    await _store(storeName).clear();
  }

  dynamic _store(String storeName) {
    if (!_storeNames.contains(storeName)) {
      throw StateError(
        'IndexedDB store is outside the active transaction: $storeName',
      );
    }
    final store = _transaction.objectStore(storeName);
    if (store == null) {
      throw StateError('IndexedDB object store is unavailable: $storeName');
    }
    return store;
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
