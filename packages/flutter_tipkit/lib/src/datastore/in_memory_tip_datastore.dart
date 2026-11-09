import 'package:flutter_tipkit/src/datastore/tip_datastore.dart';

/// A [TipDatastore] that keeps everything in memory, so tips start fresh on
/// every launch. The default datastore, and handy in tests.
class InMemoryTipDatastore implements TipDatastore {
  /// Creates a datastore, optionally starting from [initial].
  InMemoryTipDatastore([TipStoreSnapshot initial = const TipStoreSnapshot()])
    : _tips = {...initial.tips},
      _parameters = {...initial.parameters},
      _events = {
        for (final MapEntry(:key, :value) in initial.events.entries)
          key: [...value],
      },
      _global = initial.global;

  final Map<String, TipRecord> _tips;
  final Map<String, Object?> _parameters;
  final Map<String, List<DateTime>> _events;
  TipGlobalRecord _global;

  /// What is stored right now.
  TipStoreSnapshot get snapshot => TipStoreSnapshot(
    tips: Map.unmodifiable(_tips),
    parameters: Map.unmodifiable(_parameters),
    events: Map.unmodifiable({
      for (final MapEntry(:key, :value) in _events.entries)
        key: List<DateTime>.unmodifiable(value),
    }),
    global: _global,
  );

  @override
  Future<TipStoreSnapshot> load() async => snapshot;

  @override
  Future<void> writeTip(String tipId, TipRecord? record) async {
    if (record == null) {
      _tips.remove(tipId);
    } else {
      _tips[tipId] = record;
    }
  }

  @override
  Future<void> writeParameter(String parameterId, Object? value) async {
    _parameters[parameterId] = value;
  }

  @override
  Future<void> writeEvent(String eventId, List<DateTime> donations) async {
    _events[eventId] = [...donations];
  }

  @override
  Future<void> writeGlobal(TipGlobalRecord record) async {
    _global = record;
  }

  @override
  Future<void> clear() async {
    _tips.clear();
    _parameters.clear();
    _events.clear();
    _global = const TipGlobalRecord();
  }
}
