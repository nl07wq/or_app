import 'orlo_sync_adapter.dart';
import '../../training/sync/training_sync_adapter.dart';

class OrloSyncTypeDefinition {
  const OrloSyncTypeDefinition({
    required this.id,
    required this.displayName,
    required this.schemaVersion,
    this.adapter,
  });

  final String id;
  final String displayName;
  final String schemaVersion;
  final OrloSyncAdapter? adapter;
  bool get isAvailable => adapter != null;
}

class OrloSyncTypeRegistry {
  OrloSyncTypeRegistry({Iterable<OrloSyncTypeDefinition>? definitions})
    : _definitions = {
        for (final value in definitions ?? defaults) value.id: value,
      };

  static const defaults = [
    OrloSyncTypeDefinition(
      id: 'training',
      displayName: 'TRAINING SYNC',
      schemaVersion: '1.0',
    ),
    OrloSyncTypeDefinition(
      id: 'food',
      displayName: 'FOOD SYNC',
      schemaVersion: '1.0',
    ),
    OrloSyncTypeDefinition(
      id: 'dailyLog',
      displayName: 'DAILY LOG SYNC',
      schemaVersion: '1.0',
    ),
  ];

  factory OrloSyncTypeRegistry.production() => OrloSyncTypeRegistry(
    definitions: [
      OrloSyncTypeDefinition(
        id: 'training',
        displayName: 'TRAINING SYNC',
        schemaVersion: '1.0',
        adapter: TrainingSyncAdapter(),
      ),
      defaults[1],
      defaults[2],
    ],
  );

  final Map<String, OrloSyncTypeDefinition> _definitions;

  OrloSyncTypeDefinition? find(String id) => _definitions[id];
  Iterable<OrloSyncTypeDefinition> get definitions => _definitions.values;
}
