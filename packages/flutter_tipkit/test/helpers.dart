import 'package:flutter_tipkit/flutter_tipkit.dart';

/// A tip built from its parts, for tests.
class TestTip extends Tip {
  const TestTip(
    this.id, {
    this.title = 'Title',
    this.message,
    this.actions = const [],
    this.rules = const [],
    this.options = const [],
  });

  @override
  final String id;

  final String title;
  final String? message;
  final List<TipAction> actions;

  @override
  final List<TipRule> rules;

  @override
  final List<TipOption> options;

  @override
  TipContent get content =>
      TipContent(title: title, message: message, actions: actions);
}

/// A clock the test moves by hand.
class TestClock {
  TestClock([DateTime? start]) : now = start ?? DateTime.utc(2026, 1, 1, 12);

  DateTime now;

  DateTime call() => now;

  void advance(Duration duration) => now = now.add(duration);
}

/// A datastore that records every write, in order.
class RecordingDatastore extends InMemoryTipDatastore {
  RecordingDatastore([super.initial]);

  final List<String> writes = [];

  @override
  Future<void> writeTip(String tipId, TipRecord? record) async {
    // Lets a later write overtake this one if writes were not queued.
    await Future<void>.delayed(Duration.zero);
    writes.add('tip:$tipId');
    await super.writeTip(tipId, record);
  }

  @override
  Future<void> writeParameter(String parameterId, Object? value) async {
    writes.add('parameter:$parameterId=$value');
    await super.writeParameter(parameterId, value);
  }

  @override
  Future<void> writeEvent(String eventId, List<DateTime> donations) async {
    writes.add('event:$eventId:${donations.length}');
    await super.writeEvent(eventId, donations);
  }

  @override
  Future<void> writeGlobal(TipGlobalRecord record) async {
    writes.add('global:${record.lastNewTipId}');
    await super.writeGlobal(record);
  }
}
