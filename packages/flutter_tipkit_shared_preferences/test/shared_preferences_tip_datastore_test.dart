import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tipkit/flutter_tipkit.dart';
import 'package:flutter_tipkit_shared_preferences/flutter_tipkit_shared_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  final record = TipRecord(
    displayCount: 2,
    firstDisplayedAt: DateTime.utc(2025),
    lastDisplayedAt: DateTime.utc(2026),
    invalidatedAt: DateTime.utc(2026, 2),
    invalidationReason: TipInvalidationReason.actionPerformed,
  );
  final global = TipGlobalRecord(
    lastNewTipId: 'a',
    lastNewTipShownAt: DateTime.utc(2026, 3),
  );

  Future<void> writeEverything(TipDatastore datastore) async {
    await datastore.writeTip('a', record);
    await datastore.writeTip('b', const TipRecord(displayCount: 1));
    await datastore.writeParameter('count', 3);
    await datastore.writeParameter('names', ['x', 'y']);
    await datastore.writeParameter('nothing', null);
    await datastore.writeEvent('opened', [
      DateTime.utc(2025),
      DateTime.utc(2026),
    ]);
    await datastore.writeGlobal(global);
  }

  void expectEverything(TipStoreSnapshot snapshot) {
    expect(snapshot.tips, {'a': record, 'b': const TipRecord(displayCount: 1)});
    expect(snapshot.parameters, {
      'count': 3,
      'names': ['x', 'y'],
      'nothing': null,
    });
    expect(snapshot.events, {
      'opened': [DateTime.utc(2025), DateTime.utc(2026)],
    });
    expect(snapshot.global, global);
  }

  group('cached API', () {
    setUp(() => SharedPreferences.setMockInitialValues({'other': 'kept'}));

    test('round-trips everything', () async {
      final preferences = await SharedPreferences.getInstance();
      await writeEverything(SharedPreferencesTipDatastore(preferences));
      expectEverything(await SharedPreferencesTipDatastore(preferences).load());
    });

    test('deleting a tip and clearing touch only its own keys', () async {
      final preferences = await SharedPreferences.getInstance();
      final datastore = SharedPreferencesTipDatastore(preferences);
      await writeEverything(datastore);
      await datastore.writeTip('a', null);
      expect((await datastore.load()).tips.keys, ['b']);

      await datastore.clear();
      final snapshot = await datastore.load();
      expect(snapshot.tips, isEmpty);
      expect(snapshot.parameters, isEmpty);
      expect(snapshot.events, isEmpty);
      expect(snapshot.global, const TipGlobalRecord());
      expect(preferences.getString('other'), 'kept');
    });

    test('separate prefixes do not see each other', () async {
      final preferences = await SharedPreferences.getInstance();
      await writeEverything(
        SharedPreferencesTipDatastore(preferences, keyPrefix: 'one.'),
      );
      final other = SharedPreferencesTipDatastore(
        preferences,
        keyPrefix: 'two.',
      );
      expect((await other.load()).tips, isEmpty);
    });

    test('skips corrupt entries', () async {
      SharedPreferences.setMockInitialValues({
        'tipkit.tip.broken': '{not json',
        'tipkit.tip.wrongType': '[1, 2]',
        'tipkit.tip.ok': '{"displayCount": 4}',
      });
      final preferences = await SharedPreferences.getInstance();
      final snapshot = await SharedPreferencesTipDatastore(preferences).load();
      expect(snapshot.tips, {'ok': const TipRecord(displayCount: 4)});
    });
  });

  group('async API', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('round-trips everything', () async {
      final preferences = SharedPreferencesAsync();
      await writeEverything(SharedPreferencesTipDatastore.async(preferences));
      expectEverything(
        await SharedPreferencesTipDatastore.async(preferences).load(),
      );
    });

    test('works as the datastore of Tips', () async {
      Tips.resetForTesting();
      addTearDown(Tips.resetForTesting);
      final datastore = SharedPreferencesTipDatastore.async(
        SharedPreferencesAsync(),
      );
      await Tips.configure(datastore: datastore);
      const tip = _Tip();
      tip.invalidate(TipInvalidationReason.tipClosed);
      await Tips.flush();

      Tips.resetForTesting();
      await Tips.configure(datastore: datastore);
      expect(tip.status, const TipInvalidated(TipInvalidationReason.tipClosed));
    });
  });
}

class _Tip extends Tip {
  const _Tip();

  @override
  String get id => 'tip';

  @override
  TipContent get content => const TipContent(title: 'Tip');
}
